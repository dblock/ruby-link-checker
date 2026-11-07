# frozen_string_literal: true
require 'spec_helper'

describe LinkChecker::Checker do
    context 'config' do
    it 'requires at least one method' do
      expect { LinkChecker::Checker.new(methods: []) }.to raise_error ArgumentError, 'Missing methods.'
    end

    it 'rejects an invalid redirect limit' do
      expect { described_class.new(max_redirects: -1) }.to raise_error ArgumentError, 'Invalid redirect limit: -1'
    end
  end
end