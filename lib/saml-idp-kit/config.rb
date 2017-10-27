module SamlIdpKit
  class << self
    attr_accessor :secret_key, :algorithm, :certificate, :fingerprint
    
    def configure
      yield(self)
      self.freeze
    end
  end
end
