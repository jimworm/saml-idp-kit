require_relative 'lib/saml-idp-kit'

Gem::Specification.new do |s|
  s.name          = 'saml-idp-kit'
  s.version       = SamlIdpKit::VERSION
  s.authors       = "Jimworm"
  s.email         = 'jimworm@gmail.com'
  s.homepage      = 'https://github.com/jimworm/saml-idp-kit'
  s.summary       = 'SAML IdP tools'
  s.description   = 'SAML tools to decode requests and encode assertions, for use as an identity provider'
  s.date          = '2017-11-01'
  s.files         = Dir.glob("lib/**/*") + ["MIT-LICENSE",
                                            "README.md",
                                            "Gemfile",
                                            "ruby-saml-idp.gemspec"]
  s.require_paths = ["lib"]
  s.rdoc_options  = ["--charset=UTF-8"]
  s.add_dependency('uuid')
  s.add_dependency('nokogiri')
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "ruby-saml"
end
