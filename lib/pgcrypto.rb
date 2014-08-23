require 'active_record/connection_adapters/postgresql_adapter'
require 'pgcrypto/active_record_extension'
require 'pgcrypto/key'
require 'pgcrypto/key_manager'
require 'pgcrypto/table_manager'

module PGCrypto
  def self.[](key)
    (@table_manager ||= TableManager.new)[key]
  end

  def self.base_adapter
    @base_adapter ||= ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  end

  def self.base_adapter=(base_adapter)
    @base_adapter = base_adapter
  end

  def self.keys
    @keys ||= KeyManager.new
  end
end

PGCrypto.keys[:public] = {:path => '.pgcrypto'} if File.file?('.pgcrypto')
