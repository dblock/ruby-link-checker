# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Typhoeus::Hydra::Checker do
  module TestLinkChecker
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

  describe TestLinkChecker::LinkChecker do
    it_behaves_like 'a link checker'

    context 'timeout', vcr: { cassette_name: '200' } do
      before do
        allow_any_instance_of(Typhoeus::Response).to receive(:timed_out?).and_return(true)
      end

      include_context 'with url'

      it 'times out' do
        expect(result.success?).to be false
        expect(result.error?).to be true
        expect(result.to_s).to eq 'GET https://www.example.org: ERROR (Timeout::Error)'
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
end
