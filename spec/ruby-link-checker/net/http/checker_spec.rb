# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Net::HTTP::Checker do
  before :all do
    VCR.configure do |config|
      config.hook_into :webmock
    end
  end

  it_behaves_like 'a link checker'

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
