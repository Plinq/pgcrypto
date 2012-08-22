# Add lib/ to the load path
$LOAD_PATH.unshift(File.expand_path(File.join('..', 'lib'), File.dirname(__FILE__)))

# Load up our Gemfile
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :test)

# Enable coverage reporting
require 'simplecov'

# Requier and configure PGCrypto
require 'pgcrypto'

RSpec.configure do |config|
  database_config = {:adapter => 'postgresql', :database => 'pgcrypto_test', :encoding => 'utf8', :host => 'localhost'}
  postgres_config = database_config.merge(:database => 'postgres', :schema_search_path => 'public')

  # Set up the database to handle pgcrypto functions and the schema for
  # our tests
  config.before :all do
    # Connect to the local postgres schema database
    ActiveRecord::Base.establish_connection(postgres_config)

    # Create the test database if we can
    ActiveRecord::Base.connection.create_database(database_config[:database]) rescue nil

    # Now connect to the newly created database
    ActiveRecord::Base.establish_connection(database_config)

    silence_stream(STDOUT) do
      # ...and load in the pgcrypto extension
      ActiveRecord::Base.connection.execute(%[CREATE EXTENSION pgcrypto])

      # ...and then set up the pgcrypto_columns and pgcrypto_test_models fun
      ActiveRecord::Schema.define do
        create_table :pgcrypto_columns, :force => true do |t|
          t.belongs_to :owner, :polymorphic => true
          t.string :owner_table, :limit => 32
          t.string :name, :limit => 64
          t.binary :value
        end

        create_table :pgcrypto_test_models, :force => true do |t|
          t.string :name, :limit => 32
        end
      end
    end
  end

  config.before :each do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :transaction
    DatabaseCleaner.start

    ActiveRecord::Base.establish_connection(database_config)

    class PGCryptoTestModel < ActiveRecord::Base
      self.table_name = :pgcrypto_test_models
      pgcrypto :test_column
    end
  end

  config.after :all do
    # Drop the database when we exist
    ActiveRecord::Base.establish_connection(postgres_config)
    ActiveRecord::Base.connection.drop_database(database_config[:database]) rescue nil
  end

  config.after :each do
    DatabaseCleaner.clean
  end
end
