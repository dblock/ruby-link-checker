# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Typhoeus::Hydra::Checker do
  module TyphoeusTestLinkChecker
    class Task < LinkChecker::Typhoeus::Hydra::Task; end

    class LinkChecker < LinkChecker::Typhoeus::Hydra::Checker
      def check(url, options = {})
        super url, options
        @hydra.run
      end
    end
  end
  before :all do
    VCR.configure do |config|
      config.hook_into :typhoeus
    end
  end

  describe TyphoeusTestLinkChecker::LinkChecker do
    it_behaves_like 'a link checker'

    describe '.config' do
      it 'returns the Config module' do
        expect(LinkChecker::Typhoeus::Hydra.config).to eq LinkChecker::Typhoeus::Hydra::Config
      end
    end

    context 'with timeout options', vcr: { cassette_name: '200' } do
      before do
        LinkChecker::Typhoeus::Hydra.configure do |config|
          config.timeout = 5
          config.connecttimeout = 10
        end
        expect(Typhoeus::Request).to receive(:new).with(
          URI(url),
          hash_including(timeout: 5, connecttimeout: 10)
        ).and_call_original
      end

      include_context 'with url'

      it 'creates requests with a default timeout' do
        expect(result.success?).to be true
      end
    end

    context 'timeout', vcr: { cassette_name: '200' } do
      before do
        allow_any_instance_of(Typhoeus::Response).to receive(:timed_out?).and_return(true)
      end

      include_context 'with url'

      it 'times out' do
        expect(result.success?).to be false
        expect(result.error?).to be true
        expect(result.to_s).to eq 'GET https://www.example.org : ERROR (Timeout::Error)'
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

  describe LinkChecker::Typhoeus::Hydra::Result do
    describe '#code' do
      it 'returns -1 when the response raises' do
        request = instance_double(Typhoeus::Request)
        response = instance_double(Typhoeus::Response)
        allow(response).to receive(:code).and_raise(StandardError)
        result = described_class.new(URI('https://www.example.org'), 'GET', nil, request, response, {})
        expect(result.code).to eq(-1)
      end
    end
  end

  describe '#run' do
    it 'delegates to the hydra' do
      checker = described_class.new
      expect(checker.instance_variable_get(:@hydra)).to receive(:run)
      checker.run
    end
  end
end
