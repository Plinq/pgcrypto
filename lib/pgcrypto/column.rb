module PGCrypto
  class Column < ActiveRecord::Base
    self.table_name = 'pgcrypto_columns'
    before_save :set_owner_table
    belongs_to :owner, :autosave => false, :inverse_of => :pgcrypto_columns, :polymorphic => true

    protected
    def set_owner_table
      self.owner_table = self.owner.class.table_name
    end
  end
end
