require 'pgcrypto/column'

module PGCrypto
  class ColumnConverter

    def self.migrate!
      new.migrate!
    end

    def migrate!
      PGCrypto::Column.find_each(batch_size: 100) do |column|
        migrate_column(column)
      end
    end

    private

    def migrate_column(column)
      if column.owner
        column.owner.update_column(column.name, column.value)
        puts "Migrated #{column.owner}##{column.name}"
      end
    end

  end
end
