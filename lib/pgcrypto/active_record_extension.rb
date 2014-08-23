module PGCrypto
  module ActiveRecordExtension
    def pgcrypto(*pgcrypto_column_names)
      options = pgcrypto_column_names.extract_options!
      options.reverse_merge(include: false, type: :pgp)

      pgcrypto_column_names.map(&:to_s).each do |column_name|
        # Stash the encryption type in our module
        pgcrypto_columns[column_name] ||= options.symbolize_keys
      end
    end

    def pgcrypto_columns
      PGCrypto[table_name]
    end
  end
end

if defined? ActiveRecord::Base
  ActiveRecord::Base.extend PGCrypto::ActiveRecordExtension
end
