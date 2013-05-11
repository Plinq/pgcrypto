class InstallPgcrypto < ActiveRecord::Migration
  def up
    create_table :pgcrypto_columns do |t|
      t.belongs_to :owner, :polymorphic => true
      t.string :owner_table, :limit => 32
      t.string :name, :limit => 32
      t.binary :value
    end
    add_index :pgcrypto_columns, [:owner_id, :owner_type, :name], :name => :pgcrypto_type_finder
    add_index :pgcrypto_columns, [:owner_id, :owner_table, :name], :name => :pgcrypto_table_finder
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"
  end

  def down
    drop_table :pgcrypto_columns
  end
end
