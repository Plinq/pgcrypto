require 'arel/visitors/postgresql'

# We override some fun stuff in the PostgreSQL visitor class inside of Arel.
# This is the _most_ direct approach to tweaking the SQL to INSERT, SELECT,
# and UPDATE values as encrypted. Unfortunately, the visitor API doesn't
# give us access to managers as well as nodes, so we have use the public
# Arel API via the connection adapter's to_sql method. Then we tweak the
# more specific bits here!

Arel::Visitors::PostgreSQL.class_eval do
  alias :original_visit_Arel_Nodes_Assignment :visit_Arel_Nodes_Assignment
  def visit_Arel_Nodes_Assignment(assignment)
    # Hijack the normally inoccuous assignment that happens, seeing as how
    # Arel normally forwards this shit to someone else and I hate it. 
    if PGCrypto[assignment.left.relation.name][assignment.left.name]
      # raise "#{visit(assignment.left)} = #{visit(assignment.right)}"
      "#{visit(assignment.left)} = #{visit(assignment.right)}"
    else
      original_visit_Arel_Nodes_Assignment(assignment)
    end
  end
end
