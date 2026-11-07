# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Tasks do
  describe 'retry delays' do
    let(:checker) { LinkChecker::Net::HTTP::Checker.new }
    let(:tasks) { described_class.new(checker, LinkChecker::Net::HTTP::Task, 'https://www.example.org', ['GET']) }
    let(:headers) { { 'Retry-After' => '60' } }
    let(:result) { instance_double(LinkChecker::Net::HTTP::Result, response_headers: headers) }

    before do
      allow(tasks).to receive(:result).and_return(result)
    end

    it 'parses delta-seconds' do
      expect(tasks.send(:_server_retry_delay)).to eq(60)
    end

    context 'with a past HTTP date' do
      let(:headers) { { 'Retry-After' => (Time.now - 60).httpdate } }

      it 'does not delay a retry' do
        expect(tasks.send(:_server_retry_delay)).to eq(0)
      end
    end

    context 'with an invalid negative delay' do
      let(:headers) { { 'Retry-After' => '-5' } }

      it 'does not delay a retry' do
        expect(tasks.send(:_server_retry_delay)).to eq(0)
      end
    end

    it 'caps configured delays' do
      checker.retry_after = 120
      checker.max_retry_delay = 10
      expect(tasks.send(:_retry_delay)).to eq(10)
    end

    it 'adds jitter without reducing the minimum delay' do
      checker.retry_after = 2
      checker.retry_jitter = 0.5
      allow(tasks).to receive(:rand).and_return(0.5)
      expect(tasks.send(:_retry_delay)).to eq(2.5)
    end
  end

  describe '#_handle_result' do
    # Reproduces issue #12: SystemStackError when logging causes repeated errors
    # https://github.com/dblock/ruby-link-checker/issues/12
    context 'when logger.info raises an error repeatedly' do
      let(:checker) { LinkChecker::Net::HTTP::Checker.new(methods: ['GET']) }
      let(:task_klass) { LinkChecker::Net::HTTP::Task }
      let(:url) { 'https://www.example.org' }

      before do
        stub_request(:get, url).to_return(status: 200, body: '', headers: {})
      end

      it 'does not cause infinite recursion leading to SystemStackError' do
        tasks = described_class.new(checker, task_klass, url, ['GET'])

        # Stub logger to always raise an error on info, simulating the scenario
        # from issue #12 where logging causes a stack overflow due to the
        # rescue block in _handle_result recursively calling itself
        allow(tasks).to receive(:logger).and_return(
          instance_double(LinkChecker::Logger).tap do |logger|
            allow(logger).to receive(:info).and_raise(StandardError, 'stack level too deep')
            allow(logger).to receive(:error)
          end
        )

        # Should not raise SystemStackError - the error should be handled gracefully
        expect { tasks.execute! }.not_to raise_error
      end
    end
  end

  describe '#retries' do
    let(:checker) { LinkChecker::Net::HTTP::Checker.new(methods: ['GET'], retries: 2) }
    let(:task_klass) { LinkChecker::Net::HTTP::Task }
    let(:url) { 'https://www.example.org' }

    it 'delegates to the checker' do
      tasks = described_class.new(checker, task_klass, url, ['GET'])
      expect(tasks.send(:retries)).to eq 2
    end
  end
end
