require 'active_record/connection_adapters/postgresql_adapter'
require 'pgcrypto/has_encrypted_column'
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
    rebuild_adapter! if respond_to?(:rebuild_adapter!)
  end

  def self.keys
    @keys ||= KeyManager.new
  end
end

PGCrypto.keys[:public] = {:path => '.pgcrypto'} if File.file?('.pgcrypto')

require 'pgcrypto/railtie' if defined? Rails::Railtie
