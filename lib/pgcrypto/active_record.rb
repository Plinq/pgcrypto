require 'active_record/connection_adapters/postgresql_adapter'

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  alias :original_to_sql :to_sql
  def to_sql(arel)
    case arel
    when Arel::InsertManager
      pgcrypto_tweak_insert(arel)
    when Arel::SelectManager
      pgcrypto_tweak_select(arel)
    when Arel::UpdateManager
      pgcrypto_tweak_update(arel)
    end
    original_to_sql(arel)
  end

  private
  def pgcrypto_tweak_insert(arel)
    table = arel.ast.relation.name
    unless PGCrypto[table].empty?
      arel.ast.columns.each_with_index do |column, i|
        if options = PGCrypto[table][column.name]
          if key = PGCrypto.keys[options[:public_key] || :public]
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
    # a SelectStatement, and tweaking both *what* it's selecting
    # and correcting plain-text queries against an encrypted
    # column...
    joins = {}
    arel.ast.cores.each do |core|
      # Now we loop through each SelectStatement's actual selction -
      # typically it's just '*'; and, in fact, that one of the only
      # things we care about!
      new_projections = []
      core.projections.each do |projection|
        next unless projection.respond_to?(:relation)
        # The one other situation we might care about is if the projection is
        # selecting a specifically encrypted column, in which case, we want to
        # _wrap_ it. See how that's different?
        if !PGCrypto[projection.relation.name].empty?
          # Okay, so first, check if it's a broad select
          if projection.name == '*'
            # In this case, we want to just grab all the keys from columns in this table
            # and select them fancy-like
            PGCrypto[projection.relation.name].each do |column, options|
              new_projections.push(pgcrypto_tweak_select_column(column, options, joins))
            end
          elsif options = PGCrypto[projection.relation.name][projection.name]
            # And in this case, we're just selecting a single column!
            new_projections.push(pgcrypto_tweak_select_column(projection.name, options, joins))
          end
        end
      end
      core.projections.push(*new_projections.compact)

      # Dios mio! What an operation! Now we'll do something similar for the WHERE statements
      core.wheres.each do |where|
        # Now loop through the children to encrypt them for the SELECT
        where.children.each do |child|
          if options = PGCrypto[child.left.relation.name]["#{child.left.name}_encrypted"]
            if key = PGCrypto.keys[options[:private_key] || :private]
              joins[key.name] ||= "#{key.dearmored} AS #{key.name}_key"
              child.left = Arel::Nodes::SqlLiteral.new("pgp_pub_decrypt(#{child.left.name}_encrypted, keys.#{key.name}_key)")
            end
          end
        end if where.respond_to?(:children)
      end
    end
    unless joins.empty?
      arel.join(Arel::Nodes::SqlLiteral.new("CROSS JOIN (SELECT #{joins.values.join(', ')}) AS keys"))
    end
  end

  def pgcrypto_tweak_select_column(column, options, joins)
    return nil unless options[:type] == :pgp
    if key = PGCrypto.keys[options[:private_key] || :private]
      select = %[pgp_pub_decrypt(#{column}, keys.#{key.name}_key#{", '#{key.password}'" if key.password}) AS "#{column.to_s.gsub(/_encrypted$/, '')}"]
      joins[key.name] ||= "#{key.dearmored} AS #{key.name}_key"
      Arel::Nodes::SqlLiteral.new(select)
    end
  end

  def pgcrypto_tweak_update(arel)
    # Loop through the assignments and make sure we take care of that whole
    # NULL value thing!
    arel.ast.values.each do |value|
      if value.respond_to?(:left) && options = PGCrypto[value.left.relation.name][value.left.name]
        if value.right.nil?
          value.right = Arel::Nodes::SqlLiteral.new('NULL')
        elsif key = PGCrypto.keys[options[:public_key] || :public]
          quoted_right = quote_string(value.right)
          encryption_instruction = %[pgp_pub_encrypt('#{quoted_right}', #{key.dearmored})]
          value.right = Arel::Nodes::SqlLiteral.new(encryption_instruction)
        end
      end
    end
  end
end