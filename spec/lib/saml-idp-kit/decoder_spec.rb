require 'spec_helper'

describe "SamlIdpKit::Decoder", type: :lib do
  describe "#decode" do
    let(:decoder)  { SamlIdpKit::Decoder.new }
    let(:fakeuuid) { 'testvalue' }
    let(:settings) { OneLogin::RubySaml::Settings.new(issuer: 'https://consumer.example.com',
                                                      assertion_consumer_service_url: 'https://consumer.example.com/login',
                                                      idp_sso_target_url: 'https://authorizer.example.com/saml') }
    let(:request)  { OneLogin::RubySaml::Authrequest.new.create_params(settings) }
    
    before { allow(OneLogin::RubySaml::Utils).to receive(:uuid).and_return(fakeuuid) }
    
    it "decodes the given saml request with the correct information" do
      decoded = decoder.decode(request['SAMLRequest'])
      expect(decoded[:acs_url]).to    eq 'https://consumer.example.com/login'
      expect(decoded[:issuer]).to     eq 'https://consumer.example.com'
      expect(decoded[:request_id]).to eq fakeuuid
    end
  end
end
