# frozen_string_literal: true
require 'spec_helper'

describe LinkChecker::Checker do
    context 'config' do
    it 'requires at least one method' do
      expect { LinkChecker::Checker.new(methods: []) }.to raise_error ArgumentError, 'Missing methods.'
    end
  end
end