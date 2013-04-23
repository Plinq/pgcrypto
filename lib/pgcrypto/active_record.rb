require 'active_record/connection_adapters/postgresql_adapter'

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  unless instance_methods.include?(:to_sql_without_pgcrypto) || instance_methods.include?('to_sql_without_pgcrypto')
    alias :to_sql_without_pgcrypto :to_sql
  end

  def to_sql(arel, *args)
    case arel
    when Arel::InsertManager
      pgcrypto_tweak_insert(arel)
    when Arel::SelectManager
      pgcrypto_tweak_select(arel)
    when Arel::UpdateManager
      pgcrypto_tweak_update(arel)
    end
    to_sql_without_pgcrypto(arel, *args)
  end

  private
  def pgcrypto_tweak_insert(arel)
    if arel.ast.relation.name.to_s == PGCrypto::Column.table_name.to_s
      return unless key = PGCrypto.keys[:public]
      arel.ast.columns.each_with_index do |column, i|
        if column.name == 'value'
          value = arel.ast.values.expressions[i]
          quoted_value = quote_string(value)
          encryption_instruction = %[pgp_pub_encrypt(#{quoted_value}, #{key.dearmored})]
          arel.ast.values.expressions[i] = Arel::Nodes::SqlLiteral.new(encryption_instruction)
        end
      end
    end
  end

  def pgcrypto_tweak_select(arel)
    return unless key = PGCrypto.keys[:private]
    # We start by looping through each "core," which is just
    # a SelectStatement and correcting plain-text queries
    # against an encrypted column...
    joins = []
    table_name = nil
    arel.ast.cores.each do |core|
      # Yeah, I'm lazy. Whatevs.
      next unless core.is_a?(Arel::Nodes::SelectCore)

      encrypted_columns = PGCrypto[table_name = core.source.left.name]
      next if encrypted_columns.empty?

      # We loop through each WHERE specification to determine whether or not the
      # PGCrypto column should be JOIN'd upon; in which case, we, like, do it.
      core.wheres.each do |where|
        if where.respond_to?(:children)
          children = where.children
        elsif where.respond_to?(:expr)
          children = [where.expr]
        else
          children = []
        end
        # Now loop through the children to encrypt them for the SELECT
        children.each do |child|
          next unless child.respond_to?(:left) and child.left.respond_to?(:name)
          column_options = encrypted_columns[child.left.name.to_s]
          next unless column_options
          joins.push(child.left.name.to_s) unless joins.include?(child.left.name.to_s)
          sql_string = %(pgp_pub_decrypt("#{PGCrypto::Column.table_name}_#{child.left.name}"."value", pgcrypto_keys.#{key.name}#{key.password?}))
          sql_string << "::#{column_options[:column_type]}" if column_options[:column_type]
          child.left = Arel::Nodes::SqlLiteral.new(sql_string)
        end
      end
    end
    if joins.any?
      arel.join(Arel::Nodes::SqlLiteral.new("CROSS JOIN (SELECT #{key.dearmored} AS #{key.name}) AS pgcrypto_keys"))
      joins.each do |column|
        column = quote_string(column)
        as_table = "#{PGCrypto::Column.table_name}_#{column}"
        arel.join(Arel::Nodes::SqlLiteral.new(%[
          JOIN "#{PGCrypto::Column.table_name}" AS "#{as_table}" ON "#{as_table}"."owner_id" = "#{table_name}"."id" AND "#{as_table}"."owner_table" = '#{quote_string(table_name)}' AND "#{as_table}"."name" = '#{column}'
        ]))
      end
    end
  end

  def pgcrypto_tweak_update(arel)
    if arel.ast.relation.name.to_s == PGCrypto::Column.table_name.to_s
      # Loop through the assignments and make sure we take care of that whole
      # NULL value thing!
      value = arel.ast.values.select{|value| value.respond_to?(:left) && value.left.name == 'value' }.first
      if value.right.nil?
        value.right = Arel::Nodes::SqlLiteral.new('NULL')
      elsif key = PGCrypto.keys[:public]
        quoted_right = quote_string(value.right)
        encryption_instruction = %[pgp_pub_encrypt('#{quoted_right}', #{key.dearmored})]
        value.right = Arel::Nodes::SqlLiteral.new(encryption_instruction)
      end
    end
  end
end
