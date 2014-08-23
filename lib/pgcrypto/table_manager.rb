require 'pgcrypto/table'

module PGCrypto
  class TableManager < Table
    def [](key)
      return {} unless key
      super(key) || self[key] = Table.new
    end
  end
end
