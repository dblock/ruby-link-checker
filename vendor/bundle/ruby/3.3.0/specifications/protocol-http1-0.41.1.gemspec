# -*- encoding: utf-8 -*-
# stub: protocol-http1 0.41.1 ruby lib

Gem::Specification.new do |s|
  s.name = "protocol-http1".freeze
  s.version = "0.41.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "documentation_uri" => "https://socketry.github.io/protocol-http1/", "source_code_uri" => "https://github.com/socketry/protocol-http1.git" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Samuel Williams".freeze, "Thomas Morgan".freeze, "Anton Zhuravsky".freeze, "Brian Morearty".freeze, "Bruno Sutic".freeze, "Olle Jonsson".freeze]
  s.cert_chain = ["-----BEGIN CERTIFICATE-----\nMIIEFDCCAnygAwIBAgIBATANBgkqhkiG9w0BAQsFADAwMREwDwYDVQQKDAhTb2Nr\nZXRyeTEbMBkGA1UEAwwSU29ja2V0cnkgUnVieSBHZW1zMB4XDTI2MDkyMTA3NTgx\nNFoXDTI3MDkyMTA3NTgxNFowMDERMA8GA1UECgwIU29ja2V0cnkxGzAZBgNVBAMM\nElNvY2tldHJ5IFJ1YnkgR2VtczCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoC\nggGBAM/QgjVgDzDo/xJEQoFvAzcVFP7msnswkhPJB2UDsbxXCZmers5jV512TM5s\nNwLHfzJiC4DcI5ax9ZYKM9Q+dS21YYagNqjtg3YPyDqR6phoibEA0VoMuInUQW68\ni5OkCJzYKGD2pYYVZnuFNqyM2ECUvXh/fBmvPoHbncAHhWPaCBH8mQJ8sRNc6+RV\nSoZZu1Yo/aW1zQ+SpZwad7s1ZmigfDNHKhJ22KwZHk+/5Zw1QXVfcajjswV0Mm2P\nirgjKN3fyNVkwlly63EBlR4VydT+g9QtJtqh7ee0ThhI+v4wYovf4dbLNcEBTHu1\nx1pGbXGx/2fBAST5eVwaXIx1V8VU22AJcBk1H2o5/1F0HfbD2HQjmFOA112KUwBW\n9TtspZD3g6rCQFX53XvL9h6j2y1ukl7s5AdEzOe/x6r1MO8tSDtgcYoF89wgF/88\nQ/Eski0FckQ+znfESZcFcpzs2sPDoYW6SNVX4tZcNty85Y6WBHfHKio14x63PeyC\nCG1gMwIDAQABozkwNzAJBgNVHRMEAjAAMAsGA1UdDwQEAwIEsDAdBgNVHQ4EFgQU\nSuMc0x24Xshtaa8SQVkBr2Z5WzIwDQYJKoZIhvcNAQELBQADggGBABI62ey5lDWm\nj8jsTQaNBMBb7LbKS3XkBwyL1UNGEwlicp399rJDeuNgVSHqBCZ/nE4yleNjgW9Y\nN6DKdxXCvXmFUoHvUINeAvThHxmlEGhSfXl1x55xHEig0rEP4jgdjnYdQI4fqeOM\nzIDN0F3ruArke4Y62SQgWVN7vspdAA41hBIRl1vsvs0KWG8DIVQ8cmR+TG6zjOmK\niUiUZGNPnStV1O1xW83c+Ba4Am0krP6/forxDPhRvTehqkVYvMdPfYcICNb5IM58\n5vaYvuj5AtfZuZWN0F/0KtSphhNC17rh6h8QmuYdMJ1clvlrkiEaO1UjPVwjgtxC\nx/ARh5X6q0/YTXl4r7EfSJEeqW7qhgu9EUj3mGIPHYdX0Dqih/NgK20F3GvQtTfB\n7sse0duKBHXONYVwKAsceUVvqtCfyF608bCilCkbhw3QaInRj+BkRQKJ5Tuj2PZR\n76a/hwaV2wWn5RtAFBaUQzQdo/xTqJ7IkwaFjOZe/QyvyoRjCK9Rdg==\n-----END CERTIFICATE-----\n".freeze]
  s.date = "1980-01-02"
  s.homepage = "https://github.com/socketry/protocol-http1".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.3".freeze)
  s.rubygems_version = "4.0.21".freeze
  s.summary = "A low level implementation of the HTTP/1 protocol.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<protocol-http>.freeze, ["~> 0.68".freeze])
end
