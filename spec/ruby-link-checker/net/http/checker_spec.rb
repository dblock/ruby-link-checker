# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Net::HTTP::Checker do
  before :all do
    VCR.configure do |config|
      config.hook_into :webmock
    end
  end

  after do
    LinkChecker::Net::HTTP::Config.reset
  end

  it_behaves_like 'a link checker'

  context 'with timeout options', vcr: { cassette_name: '200' } do
    before do
      LinkChecker::Net::HTTP.configure do |config|
        config.read_timeout = 5
        config.open_timeout = 10
      end
      expect_any_instance_of(Net::HTTP).to receive(:read_timeout=).with(5)
      expect_any_instance_of(Net::HTTP).to receive(:open_timeout=).with(10)
    end

    include_context 'with url'

    it 'creates requests with a default timeout' do
      expect(result.success?).to be true
    end
  end

  context 'timeout' do
    before do
      stub_request(:get, 'https://www.example.org/').to_timeout
    end

    include_context 'with url'

    around do |example|
      VCR.turned_off { example.run }
    end

    it 'times out' do
      expect(result.success?).to be false
      expect(result.error?).to be true
      expect(result.to_s).to eq 'GET https://www.example.org: ERROR (Net::OpenTimeout)'
    end

    context 'with metadata' do
      let(:options) { { foo: :bar } }

      it 'times out' do
        expect(result.error?).to be true
        expect(result.options).to eq(foo: :bar)
      end
    end
  end
end
