require 'rails/generators/migration'
require 'rails/generators/active_record'

module Pgcrypto
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path('../templates', __FILE__)

      def copy_migration
        migration_template("migration.rb", "db/migrate/install_pgcrypto")
      end

      def create_initializer
        copy_file("initializer.rb", "config/initializers/pgcrypto.rb")
      end

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end
  end
end
