require 'rubygems'
require 'simplecov'

# Add lib/ to the load path
$LOAD_PATH.unshift(File.expand_path(File.join('..', 'lib'), File.dirname(__FILE__)))

require 'database_cleaner'

gem 'activerecord', ENV.fetch('ACTIVE_RECORD_VERSION', '>= 4.0')
require 'active_record'
require 'pgcrypto'

RSpec.configure do |config|
  database_config = {
    adapter: 'pgcrypto',
    database: '__pgcrypto_gem_test',
    encoding: 'utf8',
    host: 'localhost'
  }
  postgres_config = database_config.merge(:database => 'postgres', :schema_search_path => 'public')

  # Set up the database to handle pgcrypto functions and the schema for
  # our tests
  config.before :suite do
    # Connect to the local postgres schema database
    ActiveRecord::Base.establish_connection(postgres_config)

    # Create the test database if we can
    ActiveRecord::Base.connection.create_database(database_config[:database]) rescue nil

    # Now connect to the newly created database
    ActiveRecord::Base.establish_connection(database_config)

    silence_stream(STDOUT) do
      # ...and load in the pgcrypto extension
      ActiveRecord::Base.connection.execute(%[CREATE EXTENSION pgcrypto]) rescue nil

      # ...and then set up the pgcrypto_columns and pgcrypto_test_models fun
      ActiveRecord::Schema.define do
        create_table :pgcrypto_test_models, :force => true do |t|
          t.string :name, :limit => 32
          t.binary :encrypted_text
        end
      end
    end

    ActiveRecord::Base.establish_connection(database_config)

    DatabaseCleaner.strategy = :transaction
  end

  config.before :each do
    DatabaseCleaner.start

    class PGCryptoTestModel < ActiveRecord::Base
      self.table_name = :pgcrypto_test_models
      has_encrypted_column :encrypted_text
    end
  end

  config.after :each do
    DatabaseCleaner.clean
  end

  config.after :suite do
    # Drop the database when we exit
    ActiveRecord::Base.establish_connection(postgres_config)
    ActiveRecord::Base.connection.drop_database(database_config[:database]) rescue nil
  end

end
