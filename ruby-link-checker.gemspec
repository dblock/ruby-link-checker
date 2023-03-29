# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'ruby-link-checker/version'

Gem::Specification.new do |s|
  s.name = 'ruby-link-checker'
  s.version = Ruby::LinkChecker::VERSION
  s.authors = ['Daniel Doubrovkine']
  s.email = 'dblock@dblock.org'
  s.platform = Gem::Platform::RUBY
  s.required_rubygems_version = '>= 1.3.6'
  s.required_ruby_version = '>= 2.7'
  s.files = Dir['**/*']
  s.require_paths = ['lib']
  s.homepage = 'http://github.com/dblock/ruby-link-checker'
  s.licenses = ['MIT']
  s.summary = 'Fast ruby link checker.'
  s.metadata['rubygems_mfa_required'] = 'true'
end
