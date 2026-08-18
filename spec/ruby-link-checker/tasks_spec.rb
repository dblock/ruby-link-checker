# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Tasks do
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
end
