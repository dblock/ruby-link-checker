# -*- encoding: utf-8 -*-
# stub: danger 9.6.1 ruby lib

Gem::Specification.new do |s|
  s.name = "danger".freeze
  s.version = "9.6.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Orta Therox".freeze, "Juanito Fatas".freeze]
  s.date = "1980-01-02"
  s.description = "Stop Saying 'You Forgot To\u2026' in Code Review".freeze
  s.email = ["orta.therox@gmail.com".freeze, "katehuang0320@gmail.com".freeze]
  s.executables = ["danger".freeze]
  s.files = ["bin/danger".freeze]
  s.homepage = "https://github.com/danger/danger".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7.0".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Like Unit Tests, but for your Team Culture.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<base64>.freeze, ["~> 0.2".freeze])
  s.add_runtime_dependency(%q<claide>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<claide-plugins>.freeze, [">= 0.9.2".freeze])
  s.add_runtime_dependency(%q<colored2>.freeze, [">= 3.1".freeze, "< 5".freeze])
  s.add_runtime_dependency(%q<cork>.freeze, ["~> 0.1".freeze])
  s.add_runtime_dependency(%q<faraday>.freeze, [">= 0.9.0".freeze, "< 3.0".freeze])
  s.add_runtime_dependency(%q<faraday-http-cache>.freeze, ["~> 2.0".freeze])
  s.add_runtime_dependency(%q<git>.freeze, [">= 1.13".freeze])
  s.add_runtime_dependency(%q<kramdown>.freeze, [">= 2.5.1".freeze, "< 3.0".freeze])
  s.add_runtime_dependency(%q<kramdown-parser-gfm>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<octokit>.freeze, [">= 4.0".freeze])
  s.add_runtime_dependency(%q<pstore>.freeze, ["~> 0.1".freeze])
  s.add_runtime_dependency(%q<terminal-table>.freeze, [">= 1".freeze, "< 5".freeze])
end
