require 'pgcrypto/generators/base_generator'

module Pgcrypto
  module Generators
    class InstallGenerator < BaseGenerator

      source_root File.expand_path('../templates', __FILE__)

      def copy_migration
        migration_template("migration.rb", "db/migrate/install_pgcrypto")
      end

      def create_initializer
        copy_file("initializer.rb", "config/initializers/pgcrypto.rb")
      end
    end
  end
end
