require 'pgcrypto/column'
require 'pgcrypto/column_converter'

class UpgradePgcryptoTo040 < ActiveRecord::Migration
  def up
    # Add columns based on the ones we already know exist
    PGCrypto::Column.tables_and_columns do |table, column|
      add_column table, column, :binary
    end

    # Migrate column data
    PGCrypto::ColumnConverter.migrate!

    # Drop the old, now-unused columns table
    # COMMENT THIS IN IF YOU REALLY WANT IT
    # drop_table :pgcrypto_columns
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
