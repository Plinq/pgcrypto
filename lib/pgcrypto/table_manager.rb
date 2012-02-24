module PGCrypto
  class Table < Hash
    def [](key)
      super(key.to_sym)
    end

    def []=(key, value)
      super key.to_sym, value
    end
  end

  class TableManager < Table
    def [](key)
      return {} unless key
      super(key) || self[key] = Table.new
    end
  end
end
