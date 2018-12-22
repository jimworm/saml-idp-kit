module SamlIdpKit
  class Encoder
    attr_accessor :idp_name, :secret_key, :algorithm, :certificate
    
    def initialize(options={})
      # NAME_ID_FORMAT = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      defaults = {idp_name: 'https://example.com', secret_key: SamlIdpKit.secret_key, algorithm: SamlIdpKit.algorithm, certificate: SamlIdpKit.certificate}
      options = defaults.merge(options)
      defaults.keys.each do |key|
        self.send("#{key}=", options[key])
      end
    end
    
    def encode(nameid, decoded_saml_request, opts = {})
      now = Time.now.utc
      response_id, reference_id = UUID.generate, UUID.generate
      audience_uri = opts[:audience_uri] || decoded_saml_request[:acs_url]
      
      assertion = assert(idp: idp_name,
                         requester: decoded_saml_request[:issuer],
                         audience_uri: audience_uri,
                         nameid: nameid,
                         at: now,
                         in_response_to: decoded_saml_request[:request_id],
                         reference_id: reference_id,
                         attributes: opts[:attributes])
      
      signed_info = Nokogiri::XML::DocumentFragment.parse('').tap do |signed_info|
        digest_value   = Base64.strict_encode64(algorithm.digest(canonicalize(assertion)))
        algorithm_name = begin
          full_name = algorithm.to_s
          if i = full_name.rindex("::")
            full_name[(i + 2)..-1]
          else
            full_name
          end
        end.downcase
        
        Nokogiri::XML::Builder.with(signed_info) do
          SignedInfo('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#') do
            CanonicalizationMethod('Algorithm' => 'http://www.w3.org/2001/10/xml-exc-c14n#')
            SignatureMethod('Algorithm' => "http://www.w3.org/2000/09/xmldsig#rsa-#{algorithm_name}")
            Reference('URI' => "#_#{reference_id}") do
              Transforms do
                Transform('Algorithm' => 'http://www.w3.org/2000/09/xmldsig#enveloped-signature')
                Transform('Algorithm' => 'http://www.w3.org/2001/10/xml-exc-c14n#')
              end
              DigestMethod('Algorithm' => "http://www.w3.org/2000/09/xmldsig##{algorithm_name}")
              DigestValue(digest_value)
            end
          end
        end
        signed_info_ns = signed_info.at_css('SignedInfo').add_namespace('ds', 'http://www.w3.org/2000/09/xmldsig#')
        signed_info.css('*').each{ |node| node.namespace = signed_info_ns }
      end
      
      keyinfo = Nokogiri::XML::DocumentFragment.parse('').tap do |keyinfo|
        Nokogiri::XML::Builder.with(keyinfo) do
          KeyInfo('xmlns' => 'http://www.w3.org/2000/09/xmldsig#') do
            X509Data do
              X509Certificate certificate
            end
          end
        end
      end
      
      signature = Nokogiri::XML::DocumentFragment.parse('').tap do |signature|
        value = sign(canonicalize(signed_info))
        Nokogiri::XML::Builder.with(signature) do
          Signature('xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#') do
            SignatureValue value
          end
        end
        signature_ns = signature.at_css('Signature').add_namespace('ds', 'http://www.w3.org/2000/09/xmldsig#')
        signature.css('*').each{ |node| node.namespace = signature_ns }
        signature.at_css('ds|SignatureValue', 'ds' => signature_ns.href).before(signed_info)
        signature.at_css('ds|SignatureValue', 'ds' => signature_ns.href).after(keyinfo)
        signature
      end
      
      assertion.at_css('saml|Issuer', 'saml' => 'urn:oasis:names:tc:SAML:2.0:assertion').after(signature)
      
      saml_response = Nokogiri::XML::DocumentFragment.parse('').tap do |saml_response|
        Nokogiri::XML::Builder.with(saml_response) do
          Response('ID' => "_#{response_id}", 'Version' => '2.0', 'IssueInstant' => now.iso8601,
                   'Destination' => audience_uri, 'Consent' => 'urn:oasis:names:tc:SAML:2.0:consent:unspecified',
                   'InResponseTo' => decoded_saml_request[:request_id],
                   'xmlns:saml' => "urn:oasis:names:tc:SAML:2.0:assertion",
                   'xmlns:samlp' => 'urn:oasis:names:tc:SAML:2.0:protocol') do
            Issuer(idp_name, 'xmlns' => 'urn:oasis:names:tc:SAML:2.0:assertion')
            Status do
              StatusCode('Value' => 'urn:oasis:names:tc:SAML:2.0:status:Success')
            end
          end
        end
        saml_ns = saml_response.at_css('Response').add_namespace('samlp', 'urn:oasis:names:tc:SAML:2.0:protocol')
        saml_response.at_css('*').namespace = saml_ns
        saml_response.at_css('Status').namespace = saml_ns
        saml_response.at_css('StatusCode').namespace = saml_ns
        saml_response.at_css('samlp|Status', 'samlp' => saml_ns.href).after(assertion)
        saml_response
      end
      
      Base64.encode64(saml_response.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML))
    end
    
    def form_html(target:, response:, relaystate: nil)
      relaystate = "<input type=\"hidden\" name=\"RelayState\" value=\"#{relaystate}\" />" if relaystate
      
      <<-EOS
      <!DOCTYPE html>
      <html>
      <head>
      <meta charset="utf-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
      </head>
      <body onload="document.forms[0].submit();" style="visibility:hidden;">
      <form method="post" action="#{target}">
      <input type="hidden" name="SAMLResponse" id="SAMLResponse" value="#{response}" />
      #{relaystate}
      <input type="submit" value="Submit" />
      </form>
      </body>
      </html>
      EOS
    end
    
    
    private
    def assert(idp: 'https://example.com', requester: , audience_uri:, nameid:, at:, in_response_to:, reference_id:, attributes: {})
      Nokogiri::XML::DocumentFragment.parse('').tap do |assertion|
        Nokogiri::XML::Builder.with(assertion) do
          Assertion('xmlns' => 'urn:oasis:names:tc:SAML:2.0:assertion', 'ID' => "_#{reference_id}", 'IssueInstant' => at.iso8601, 'Version' => '2.0') do
            Issuer idp
            Subject do
              NameID nameid, 'Format' => "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
              SubjectConfirmation('Method' => "urn:oasis:names:tc:SAML:2.0:cm:bearer") do
                SubjectConfirmationData('InResponseTo' => in_response_to, 'NotOnOrAfter' => (at+3*60).iso8601, 'Recipient' => audience_uri)
              end
            end
            Conditions('NotBefore' => (at-5).iso8601, 'NotOnOrAfter' => (at+60*60).iso8601) do
              AudienceRestriction do
                Audience audience_uri
              end
            end
            AttributeStatement do
              Attribute('Name' => 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress') do
                AttributeValue nameid
              end
              if attributes and attributes.is_a?(Hash)
                attributes.each do |name, value|
                  Attribute('Name' => name) { AttributeValue value.to_s }
                end
              end
            end
            AuthnStatement('AuthnInstant' => at.iso8601, 'SessionIndex' => "_#{reference_id}") do
              AuthnContext do
                AuthnContextClassRef 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password'
              end
            end
          end
        end
      end
    end
        
    def sign(data)
      key = OpenSSL::PKey::RSA.new(SamlIdpKit.secret_key)
      Base64.strict_encode64(key.sign(SamlIdpKit.algorithm.new, data))
    end
    
    def canonicalize(builder)
      Nokogiri.parse(builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)).canonicalize(Nokogiri::XML::XML_C14N_EXCLUSIVE_1_0)
    end
  end
end
