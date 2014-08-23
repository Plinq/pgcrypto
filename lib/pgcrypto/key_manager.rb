module PGCrypto
  class KeyManager < Hash
    def []=(key, value)
      unless value.is_a?(Key)
        value = Key.new(value)
      end
      value.name = key
      super key, value
    end
  end
end
