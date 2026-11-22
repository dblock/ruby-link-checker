# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Result do
  subject(:result) do
    described_class.new('https://www.example.org', 'GET', 'https://www.example.org')
  end

  describe '#retry_after_delay' do
    subject(:result) do
      response = Net::HTTPTooManyRequests.new('1.1', '429', 'Too Many Requests')
      headers.each { |key, value| response[key] = value }
      LinkChecker::Net::HTTP::Result.new(URI('https://www.example.org'), 'GET', nil, nil, response, {})
    end

    let(:headers) { { 'Retry-After' => '60' } }

    it 'parses delta-seconds' do
      expect(result.retry_after_delay).to eq(60)
    end

    context 'with a future HTTP date' do
      let(:headers) { { 'retry-after' => (Time.now + 60).httpdate } }

      it 'returns the seconds until the date' do
        expect(result.retry_after_delay).to be_within(2).of(60)
      end
    end

    context 'with a past HTTP date' do
      let(:headers) { { 'Retry-After' => (Time.now - 60).httpdate } }

      it 'does not delay' do
        expect(result.retry_after_delay).to eq(0)
      end
    end

    context 'with an invalid negative delay' do
      let(:headers) { { 'Retry-After' => '-5' } }

      it 'does not delay' do
        expect(result.retry_after_delay).to eq(0)
      end
    end

    context 'without Retry-After' do
      let(:headers) { {} }

      it 'does not delay' do
        expect(result.retry_after_delay).to eq(0)
      end
    end
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
