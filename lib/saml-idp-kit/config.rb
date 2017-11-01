module SamlIdpKit
  class << self
    attr_accessor :secret_key, :algorithm, :certificate, :fingerprint
    
    def configure
      yield(self)
      self.freeze
    end
    
    def algorithm=(name)
      @algorithm = ::OpenSSL::Digest.const_get(name.to_s.upcase, false)
    end
  end
end
