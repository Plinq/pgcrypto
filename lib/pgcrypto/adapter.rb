require 'pgcrypto'

module PGCrypto
  class Adapter < PGCrypto.base_adapter

    ADAPTER_NAME = 'PGCrypto'

    ColumnMethods.module_eval do
      def pgcrypto(*args)
        options = args.extract_options!
        column(args[0], 'binary', options)
      end
    end

    def native_database_types(*args, &block)
      types = super
      {
        pgcrypto: types[:binary]
      }.merge(types)
    end

    def to_sql(arel, *args)
      case arel
      when Arel::InsertManager
        pgcrypto_insert(arel)
      when Arel::SelectManager
        pgcrypto_select(arel)
      when Arel::UpdateManager
        pgcrypto_update(arel)
      end
      result = super(arel, *args)
      if arel.is_a? Arel::SelectManager
        #binding.pry
      end
      result
    end

    private

    def pgcrypto_decrypt_column(table_name, column_name, key)
      table = Arel::Table.new(table_name)
      column = Arel::Attribute.new(table, column_name)
      key_dearmored = Arel::Nodes::SqlLiteral.new("#{key.dearmored}#{key.password?}")
      Arel::Nodes::NamedFunction.new('pgp_pub_decrypt', [column, key_dearmored])
    end

    def pgcrypto_encrypt_string(string, key)
      string = quote_string(string)
      encryption_instruction = %[pgp_pub_encrypt(#{string}, #{key.dearmored})]
      Arel::Nodes::SqlLiteral.new(encryption_instruction)
    end

    def pgcrypto_insert(arel)
      if table = PGCrypto[arel.ast.relation.name.to_s]
        arel.ast.columns.each_with_index do |column, i|
          if options = table[column.name.to_sym]
            key = options[:key] || PGCrypto.keys[:public]
            next unless key
            # Encrypt encryptable columns
            value = arel.ast.values.expressions[i]
            arel.ast.values.expressions[i] = pgcrypto_encrypt_string(value, key)
          end
        end
      end
    end

    def pgcrypto_select(arel)
      # We start by looping through each "core," which is just
      # a SelectStatement and correcting plain-text queries
      # against an encrypted column...
      arel.ast.cores.each do |core|
        next unless core.is_a?(Arel::Nodes::SelectCore)

        pgcrypto_update_selects(core, core.projections) if core.projections
        pgcrypto_update_selects(core, core.having) if core.having

        # Loop through each WHERE to determine whether or not we need to
        # refer to its decrypted counterpart
        pgcrypto_update_wheres(core)
      end
    end

    def pgcrypto_update(arel)
      if table = PGCrypto[arel.ast.relation.name.to_s]
        # Find all columns with encryption instructions and encrypt them
        arel.ast.values.each do |value|
          if value.respond_to?(:left) && options = table[value.left.name]
            key = options[:key] || PGCrypto.keys[:public]
            next unless key

            if value.right.nil?
              value.right = Arel::Nodes::SqlLiteral.new('NULL')
            else
              value.right = pgcrypto_encrypt_string(value.right, key)
            end
          end
        end
      end
    end

    def pgcrypto_update_selects(core, selects)
      table_name = core.source.left.name
      columns = PGCrypto[table_name]
      return if columns.empty?

      untouched_columns = columns.keys.map(&:to_s)

      selects.each_with_index do |select, i|
        next unless select.respond_to?(:name)

        select_name = select.name.to_s
        if untouched_columns.include?(select_name)
          key = columns[select_name.to_sym][:private] || PGCrypto.keys[:private]
          next unless key
          decrypt = pgcrypto_decrypt_column(table_name, select_name, key)
          selects[i] = decrypt.as(select_name)
          untouched_columns.delete(select_name)
        end
      end

      splat_projection = selects.find { |select| select.respond_to?(:name) && select.name == '*' }
      if untouched_columns.any? && splat_projection
        untouched_columns.each do |column|
          key = columns[column.to_sym][:private] || PGCrypto.keys[:private]
          next unless key
          decrypt = pgcrypto_decrypt_column(table_name, column, key)
          core.projections.push(decrypt.as(column))
        end
      end
    end

    def pgcrypto_update_wheres(core)
      table_name = core.source.left.name
      columns = PGCrypto[table_name]
      return if columns.empty?

      core.wheres.each do |where|
        if where.respond_to?(:children)
          # Loop through the children to replace them with a decrypted counterpart
          where.children.each do |child|
            next unless child.respond_to?(:left) && options = columns[child.left.name.to_s]
            key = options[:private] || PGCrypto.keys[:private]
            child.left = pgcrypto_decrypt_column(table_name, child.left.name, key)
          end
        end
      end
    end

  end
end
