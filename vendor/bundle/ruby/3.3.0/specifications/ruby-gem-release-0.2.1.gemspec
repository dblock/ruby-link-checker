# -*- encoding: utf-8 -*-
# stub: ruby-gem-release 0.2.1 ruby lib

Gem::Specification.new do |s|
  s.name = "ruby-gem-release".freeze
  s.version = "0.2.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/dblock/ruby-gem-release/issues", "changelog_uri" => "https://github.com/dblock/ruby-gem-release/blob/master/CHANGELOG.md", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/dblock/ruby-gem-release" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Daniel Doubrovkine".freeze]
  s.date = "1980-01-02"
  s.description = "Reusable GitHub Actions workflow and Rake tasks for Ruby gem releases.".freeze
  s.email = ["dblock@users.noreply.github.com".freeze]
  s.homepage = "https://github.com/dblock/ruby-gem-release".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.3".freeze)
  s.rubygems_version = "4.0.20".freeze
  s.summary = "Reusable release workflow and Rake tasks for Ruby gems.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<commonmarker>.freeze, ["~> 2.10".freeze])
  s.add_runtime_dependency(%q<rake>.freeze, [">= 13".freeze])
end
