class InstallPgcrypto < ActiveRecord::Migration
  def up
    create_table :pgcrypto_columns do |t|
      t.belongs_to :owner, :polymorphic => true
      t.string :name, :limit => 64
      t.binary :value
    end
    add_index :pgcrypto_columns, [:owner_id, :owner_type, :name], :name => :pgcrypto_column_finder
  end

  def down
    drop_table :pgcrypto_columns
  end
end
