require 'active_record/connection_adapters/postgresql_adapter'

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  unless instance_methods.include?(:to_sql_without_pgcrypto) || instance_methods.include?('to_sql_without_pgcrypto')
    alias :to_sql_without_pgcrypto :to_sql
  end

  def to_sql(arel, *args)
    case arel
    when Arel::InsertManager
      pgcrypto_tweak_insert(arel, *args)
    when Arel::SelectManager
      pgcrypto_tweak_select(arel)
    when Arel::UpdateManager
      pgcrypto_tweak_update(arel)
    end
    to_sql_without_pgcrypto(arel, *args)
  end

  private
  def pgcrypto_tweak_insert(arel, *args)
    if arel.ast.relation.name == PGCrypto::Column.table_name && (binds = args.last).is_a?(Array)
      arel.ast.columns.each_with_index do |column, i|
        if column.name == 'value'
          model_column, model_class_name = binds.select {|column, value| column.name == 'owner_type' }.first
          model_class = Object.const_get(model_class_name)
          column_column, model_column_name = binds.select {|column, value| column.name == 'name' }.first
          options = PGCrypto[model_class.table_name][model_column_name]
          if options && key = PGCrypto.keys[options[:public_key] || :public]
            value = arel.ast.values.expressions[i]
            quoted_value = quote_string(value)
            encryption_instruction = %[pgp_pub_encrypt(#{quoted_value}, #{key.dearmored})]
            arel.ast.values.expressions[i] = Arel::Nodes::SqlLiteral.new(encryption_instruction)
          end
        end
      end
    end
  end

  def pgcrypto_tweak_select(arel)
    # We start by looping through each "core," which is just
    # a SelectStatement and correcting plain-text queries
    # against an encrypted column...
    joins = {}
    table_name = nil
    arel.ast.cores.each do |core|
      # Yeah, I'm lazy. Whatevs.
      next unless core.is_a?(Arel::Nodes::SelectCore) && !(columns = PGCrypto[table_name = core.source.left.name]).empty?

      # We loop through each WHERE specification to determine whether or not the
      # PGCrypto column should be JOIN'd upon; in which case, we, like, do it.
      core.wheres.each do |where|
        # Now loop through the children to encrypt them for the SELECT
        where.children.each do |child|
          if options = columns[child.left.name]
            if key = PGCrypto.keys[options[:private_key] || :private]
              join_name = "pgcrypto_column_#{child.left.name}"
              joins[join_name] ||= {:column => child.left.name, :key => "#{key.dearmored} AS #{key.name}_key"}
              child.left = Arel::Nodes::SqlLiteral.new(%[pgp_pub_decrypt("#{join_name}"."value", keys.#{key.name}_key)])
            end
          end
        end if where.respond_to?(:children)
      end
    end
    unless joins.empty?
      key_joins = []
      joins.each do |key_name, join|
        key_joins.push(join[:key])
        column = quote_string(join[:column].to_s)
        arel.join(Arel::Nodes::SqlLiteral.new(%[
          JOIN "pgcrypto_columns" AS "pgcrypto_column_#{column}" ON
            "pgcrypto_column_#{column}"."owner_id" = "#{table_name}"."id"
            AND "pgcrypto_column_#{column}"."owner_table" = '#{quote_string(table_name)}'
            AND "pgcrypto_column_#{column}"."name" = '#{column}'
        ]))
      end
      arel.join(Arel::Nodes::SqlLiteral.new("CROSS JOIN (SELECT #{key_joins.join(', ')}) AS keys"))
    end
  end

  def pgcrypto_tweak_update(arel)
    if arel.ast.relation.name == PGCrypto::Column.table_name
      # Loop through the assignments and make sure we take care of that whole
      # NULL value thing!
      value = arel.ast.values.select{|value| value.respond_to?(:left) && value.left.name == 'value' }.first
      id = arel.ast.wheres.map { |where| where.children.select { |child| child.left.name == 'id' }.first }.first.right
      if value.right.nil?
        value.right = Arel::Nodes::SqlLiteral.new('NULL')
      else column = PGCrypto::Column.select([:id, :owner_id, :owner_type, :name]).find(id)
        model_class = Object.const_get(column.owner_type)
        options = PGCrypto[model_class.table_name][column.name]
        if key = PGCrypto.keys[options[:public_key] || :public]
          quoted_right = quote_string(value.right)
          encryption_instruction = %[pgp_pub_encrypt('#{quoted_right}', #{key.dearmored})]
          value.right = Arel::Nodes::SqlLiteral.new(encryption_instruction)
        end
      end
    end
  end
end