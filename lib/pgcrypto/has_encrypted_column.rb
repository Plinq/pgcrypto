module PGCrypto
  module HasEncryptedColumn
    def has_encrypted_column(*column_names)
      options = column_names.extract_options!
      options.reverse_merge(type: :pgp)

      column_names.each do |column_name|
        # Stash the encryption type in our module
        PGCrypto[table_name][column_name.to_s] ||= options.symbolize_keys
      end
    end

    def pgcrypto(*args)
      if defined? Rails
        Rails.logger.debug "[DEPRECATION WARNING] `pgcrypto' is deprecated. Please use `has_encrypted_column' instead!"
      end
      has_encrypted_column(*args)
    end

  end
end

if defined? ActiveRecord::Base
  ActiveRecord::Base.extend PGCrypto::HasEncryptedColumn
end
