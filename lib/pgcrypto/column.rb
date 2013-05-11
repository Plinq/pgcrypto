module PGCrypto
  class Column < ActiveRecord::Base
    if defined?(Rails) && Rails::VERSION::MAJOR < 4
      attr_accessible :name
    end

    self.table_name = 'pgcrypto_columns'
    before_save :set_owner_table
    belongs_to :owner, :autosave => false, :inverse_of => :pgcrypto_columns, :polymorphic => true

    default_scope { select(%w(id owner_id owner_type owner_table)) }

    protected
    def set_owner_table
      self.owner_table = self.owner.class.table_name
    end
  end
end
