require 'arel/visitors/postgresql'

# We override some fun stuff in the PostgreSQL visitor class inside of Arel.
# This is the _most_ direct approach to tweaking the SQL to INSERT, SELECT,
# and UPDATE values as encrypted. Unfortunately, the visitor API doesn't
# give us access to managers as well as nodes, so we have use the public
# Arel API via the connection adapter's to_sql method. Then we tweak the
# more specific bits here!

Arel::Visitors::PostgreSQL.class_eval do
  unless instance_methods.include?(:visit_Arel_Nodes_Assignment_without_pgcrypto) || instance_methods.include?('visit_Arel_Nodes_Assignment_without_pgcrypto')
    alias :visit_Arel_Nodes_Assignment_without_pgcrypto :visit_Arel_Nodes_Assignment
  end

  def visit_Arel_Nodes_Assignment(assignment, *args)
    # Hijack the normally inoccuous assignment that happens, seeing as how
    # Arel normally forwards this shit to someone else and I hate it.
    if assignment.left.relation.name == PGCrypto::Column.table_name && assignment.left.name == 'value'
      "#{visit(assignment.left)} = #{visit(assignment.right)}"
    else
      visit_Arel_Nodes_Assignment_without_pgcrypto(assignment, *args)
    end
  end
end
