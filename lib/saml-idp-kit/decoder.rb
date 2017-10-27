module SamlIdpKit
  class Decoder
    def decode(saml_request)
      zstream  = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      decoded_request = Nokogiri::XML(zstream.inflate(Base64.decode64(saml_request)))
      decoded_request.remove_namespaces!
      zstream.finish
      zstream.close
      { acs_url: decoded_request.css('AuthnRequest').attribute('AssertionConsumerServiceURL').value,
        issuer: decoded_request.css('Issuer').text }
    end
  end
end
