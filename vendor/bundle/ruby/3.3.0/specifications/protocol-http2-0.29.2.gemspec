# -*- encoding: utf-8 -*-
# stub: protocol-http2 0.29.2 ruby lib

Gem::Specification.new do |s|
  s.name = "protocol-http2".freeze
  s.version = "0.29.2".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/socketry/protocol-http2/issues", "changelog_uri" => "https://github.com/socketry/protocol-http2/blob/main/releases.md", "documentation_uri" => "https://socketry.github.io/protocol-http2/", "source_code_uri" => "https://github.com/socketry/protocol-http2.git" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Samuel Williams".freeze, "Yuta Iwama".freeze, "Adam Petro".freeze, "Denis Talakevich".freeze, "Marco Concetto Rudilosso".freeze, "Olle Jonsson".freeze]
  s.date = "1980-01-02"
  s.homepage = "https://github.com/socketry/protocol-http2".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.3".freeze)
  s.rubygems_version = "4.0.21".freeze
  s.summary = "A low level implementation of the HTTP/2 protocol.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<protocol-hpack>.freeze, ["~> 1.4".freeze])
  s.add_runtime_dependency(%q<protocol-http>.freeze, ["~> 0.62".freeze])
end
