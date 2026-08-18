# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Result do
  subject(:result) do
    described_class.new('https://www.example.org', 'GET', 'https://www.example.org')
  end

  it 'defaults to not successful' do
    expect(result.success?).to be false
  end

  it 'defaults to not a failure' do
    expect(result.failure?).to be false
  end

  it 'defaults to not an error' do
    expect(result.error?).to be false
  end

  it 'defaults to not a redirect' do
    expect(result.redirect?).to be false
  end

  it 'defaults redirect_to to nil' do
    expect(result.redirect_to).to be_nil
  end

  it 'defaults request_headers to an empty hash' do
    expect(result.request_headers).to eq({})
  end

  it 'defaults code to nil' do
    expect(result.code).to be_nil
  end

  it 'defaults error to nil' do
    expect(result.error).to be_nil
  end
end
