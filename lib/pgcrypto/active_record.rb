require 'active_record/connection_adapters/postgresql_adapter'

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  unless instance_methods.include?(:to_sql_without_pgcrypto) || instance_methods.include?('to_sql_without_pgcrypto')
    alias :to_sql_without_pgcrypto :to_sql
  end

  def to_sql(arel, *args)
    case arel
    when Arel::InsertManager
      pgcrypto_tweak_insert(arel, *args)
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