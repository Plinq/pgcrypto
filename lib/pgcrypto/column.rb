module PGCrypto
  class Column < ActiveRecord::Base

    self.table_name = 'pgcrypto_columns'

    belongs_to :owner, polymorphic: true

    has_encrypted_column :value

    def self.tables_and_columns
      tables_and_columns = []
      select('DISTINCT owner_type, name').each do |column|
        tables_and_columns.push [column.owner_type.constantize.table_name, column.name]
      end
      tables_and_columns
    end

  end
end
