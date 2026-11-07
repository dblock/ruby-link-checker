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

  it 'classifies native timeouts without replacing the exception' do
    error = Net::ReadTimeout.new('timeout')
    result.error = error
    expect(result.error_type).to eq(:timeout)
    expect(result.error).to equal(error)
  end

  it 'classifies native connection failures' do
    result.error = Errno::ECONNREFUSED.new
    expect(result.error_type).to eq(:connection)
  end

  it 'does not classify programming errors as transient' do
    result.error = ArgumentError.new
    expect(result.error_type).to eq(:other)
  end
end
