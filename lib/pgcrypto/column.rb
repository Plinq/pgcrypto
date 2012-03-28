module PGCrypto
  class Column < ActiveRecord::Base
    self.table_name = 'pgcrypto_columns'
    belongs_to :owner, :autosave => false, :inverse_of => :pgcrypto_columns, :polymorphic => true
  end
end
