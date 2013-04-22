require 'pgcrypto/active_record'
require 'pgcrypto/arel'
require 'pgcrypto/column'
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
    def pgcrypto(*pgcrypto_column_names)
      options = pgcrypto_column_names.last.is_a?(Hash) ? pgcrypto_column_names.pop : {}
      options = {:include => false, :type => :pgp}.merge(options)

      has_many :pgcrypto_columns, :as => :owner, :autosave => true, :class_name => 'PGCrypto::Column', :dependent => :delete_all


      pgcrypto_column_names.map(&:to_s).each do |column_name|
        # Stash the encryption type in our module so various monkeypatches can access it later!
        PGCrypto[table_name][column_name] = options.symbolize_keys

        # Add dynamic attribute readers/writers for ActiveModel APIs
        # define_attribute_method column_name

        # Add attribute readers/writers to keep this baby as fluid and clean as possible.
        start_line = __LINE__; pgcrypto_methods = <<-PGCRYPTO_METHODS
        def #{column_name}
          return @_pgcrypto_#{column_name}.try(:value) if defined?(@_pgcrypto_#{column_name})
          @_pgcrypto_#{column_name} ||= select_pgcrypto_column(:#{column_name})
          @_pgcrypto_#{column_name}.try(:value)
        end

        # We write the attribute directly to its child value. Neato!
        def #{column_name}=(value)
          attribute_will_change!(:#{column_name}) if value != @_pgcrypto_#{column_name}.try(:value)
          if value.nil?
            pgcrypto_columns.select{|column| column.name == "#{column_name}"}.each(&:mark_for_destruction)
            remove_instance_variable("@_pgcrypto_#{column_name}") if defined?(@_pgcrypto_#{column_name})
          else
            @_pgcrypto_#{column_name} ||= pgcrypto_columns.select{|column| column.name == "#{column_name}"}.first || pgcrypto_columns.new(:name => "#{column_name}")
            pgcrypto_columns.push(@_pgcrypto_#{column_name})
            @_pgcrypto_#{column_name}.value = value
          end
        end

        def #{column_name}_changed?
          changed.include?(:#{column_name})
        end
        PGCRYPTO_METHODS

        class_eval pgcrypto_methods, __FILE__, start_line
      end

      # If any columns are set to be included in the parent record's finder,
      # we'll go ahead and add 'em!
      if PGCrypto[table_name].any?{|column, options| options[:include] }
        default_scope includes(:pgcrypto_columns)
      end
    end

    def pgcrpyto_columns
      PGCrypto[table_name]
    end
  end

  module InstanceMethods
    def self.included(base)
      base.class_eval do
        alias original_reload reload

        def reload
          self.class.pgcrpyto_columns.each do |column_name, options|
            reset_attribute! column_name
            changed_attributes.delete(column_name)
          end
          original_reload
        end
      end
    end

    def select_pgcrypto_column(column_name)
      return nil if new_record?
      # Now here's the fun part. We want the selector on PGCrypto columns to do the decryption
      # for us, so we have override the SELECT and add a JOIN to build out the decrypted value
      # whenever it's requested.
      options = PGCrypto[self.class.table_name][column_name]
      pgcrypto_column_finder = pgcrypto_columns
      if key = PGCrypto.keys[:private]
        pgcrypto_column_finder = pgcrypto_column_finder.select([
          %w(id owner_id owner_type owner_table).map {|column| %("#{PGCrypto::Column.table_name}"."#{column}")},
          %[pgp_pub_decrypt("#{PGCrypto::Column.table_name}"."value", pgcrypto_keys.#{key.name}#{key.password?}) AS "value"]
        ].flatten).joins(%[CROSS JOIN (SELECT #{key.dearmored} AS "#{key.name}") AS pgcrypto_keys])
      end
      pgcrypto_column_finder.where(:name => column_name).first
    rescue ActiveRecord::StatementInvalid => e
      case e.message
      when /^PGError: ERROR:  Wrong key or corrupt data/
        # If a column has been corrupted, we'll return nil and let the DBA
        # figure out WTF the is going on
        logger.error(e.message.split("\n").first)
        nil
      else
        raise e
      end
    end
  end
end

PGCrypto.keys[:public] = {:path => '.pgcrypto'} if File.file?('.pgcrypto')
if defined? ActiveRecord::Base
  ActiveRecord::Base.extend PGCrypto::ClassMethods
  ActiveRecord::Base.send :include, PGCrypto::InstanceMethods
end
