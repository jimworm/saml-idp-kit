require 'spec_helper'

describe "SamlIdpKit::Encoder", type: :lib do
  let(:encoder) { SamlIdpKit::Encoder.new }
  
  describe "#encode" do
    it "encodes an assertion for the given information" do
      assertion = encoder.encode('foo@example.com', {request_id: 'random', issuer: 'abc.net', acs_url: 'https://example.com/saml_login'})
      
      response = OneLogin::RubySaml::Response.new(assertion, settings: OneLogin::RubySaml::Settings.new(assertion_consumer_service_url: 'https://example.com/saml_login',
                                                                                                        idp_cert_fingerprint: SamlIdpKit.fingerprint))
      expect(response.is_valid?).to be_truthy
      expect(response.nameid).to         eq("foo@example.com")
      expect(response.issuers).to        include("https://example.com")
      expect(response.in_response_to).to eq('random')
    end
  end
  
  describe "#form_html" do
    let(:target)     { 'zippity' }
    let(:response)   { 'doodah' }
    let(:relaystate) { 'boobity' }
    
    it "includes the target, response, and relaystate" do
      html = encoder.form_html(target: 'zippity', response: 'doodah', relaystate: 'boobity')
      expect(html).to include(target, response, relaystate)
    end
    
    it "does not require relaystate" do
      html = encoder.form_html(target: 'zippity', response: 'doodah')
      expect(html).not_to include('RelayState')
    end
  end
end
