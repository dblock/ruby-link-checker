# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::ResultError do
  subject(:result) do
    described_class.new('https://www.example.org', 'GET', 'https://www.example.org', StandardError.new('oops'))
  end

  it 'is an error' do
    expect(result.error?).to be true
  end

  it 'returns the error class name as code' do
    expect(result.code).to eq 'StandardError'
  end
end
