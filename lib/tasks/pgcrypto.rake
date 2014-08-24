namespace :pgcrypto do
  desc "Migrate PGCrypto 0.3.x-style columns to 0.4 style"
  task migrate_old_columns: :environment do
    require 'pgcrypto/column_converter'
    PGCrypto::ColumnConverter.migrate!
  end
end
