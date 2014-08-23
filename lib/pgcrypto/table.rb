module PGCrypto
  class Table < Hash
    def [](key)
      super(key.to_sym)
    end

    def []=(key, value)
      super key.to_sym, value
    end
  end
end
