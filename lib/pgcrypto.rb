require 'pgcrypto/active_record'
require 'pgcrypto/arel'
require 'pgcrypto/key'
require 'pgcrypto/table_manager'

module PGCrypto
  class << self
    def [](key)
      (@table_manager ||= TableManager.new)[key]
    end

    def keys
      @keys ||= KeyManager.new
    end
  end

  class Error < StandardError; end

  module ClassMethods
    def pgcrypto(*column_names)

      options = column_names.last.is_a?(Hash) ? column_names.pop : {}
      options = {:type => :pgp}.merge(options)

      column_names.map(&:to_s).each do |column_name|
        encrypted_column_name = "#{column_name}_encrypted"
        unless columns_hash[encrypted_column_name]
          puts "WARNING: You defined #{column_name} as an encrypted column, but you don't have a corresponding #{encrypted_column_name} column in your database!"
        end

        # Stash the encryption type in our module so various monkeypatches can access it later!
        PGCrypto[table_name][encrypted_column_name] = options.symbolize_keys!

        # Add attribute readers/writers to keep this baby as fluid and clean as possible.
        class_eval <<-encrypted_attribute_writer
        def #{column_name}
          @attributes["#{column_name}"]
        end

        # We write the attribute twice - once as the alias so the accessor keeps working, and once
        # so the actual attribute value is dirty and will be queued up for assignment
        def #{column_name}=(value)
          @attributes["#{column_name}"] = value
          write_attribute(:#{encrypted_column_name}, value)
        end
        encrypted_attribute_writer
        # Did you notice how I was all, "clean as possible" before I fucked w/AR's internal
        # instance variables rather than use the API? *Hilarious.*
      end
    end
  end
end

PGCrypto.keys[:public] = {:path => '.pgcrypto'} if File.file?('.pgcrypto')

ActiveRecord::Base.extend PGCrypto::ClassMethods if defined? ActiveRecord::Base
