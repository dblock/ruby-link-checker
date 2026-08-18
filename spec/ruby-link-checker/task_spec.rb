# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Task do
  subject(:task) do
    described_class.new(
      LinkChecker::Net::HTTP::Checker.new,
      'https://www.example.org',
      'GET',
      'https://www.example.org'
    )
  end

  describe '#run!' do
    it 'raises NotImplementedError' do
      expect { task.run! }.to raise_error NotImplementedError
    end
  end
end
