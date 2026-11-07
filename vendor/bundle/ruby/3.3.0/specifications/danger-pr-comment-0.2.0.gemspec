# -*- encoding: utf-8 -*-
# stub: danger-pr-comment 0.2.0 ruby lib

Gem::Specification.new do |s|
  s.name = "danger-pr-comment".freeze
  s.version = "0.2.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Andrei Subbota".freeze]
  s.date = "2026-11-07"
  s.description = "Shared Dangerfile that exports a JSON report for posting Danger results as a PR comment.".freeze
  s.email = ["numbata@users.noreply.github.com".freeze]
  s.homepage = "https://github.com/numbata/danger-pr-comment".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.5.22".freeze
  s.summary = "Reusable workflows and shared Dangerfile for PR comment reporting.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<danger>.freeze, ["~> 9".freeze])
end
