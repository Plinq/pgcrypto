require 'pgcrypto/generators/base_generator'

module Pgcrypto
  module Generators
    class UpgradeGenerator < BaseGenerator

      source_root File.expand_path('../templates', __FILE__)

      def copy_migration
        migration_template("migration.rb", "db/migrate/upgrade_pgcrypto_to_0_4_0.rb")
      end

    end
  end
end
