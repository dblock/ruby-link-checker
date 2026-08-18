# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Errors::RedirectLoopError do
  subject(:error) do
    described_class.new(['https://www.example.org', 'https://www.example.org/redirect'])
  end

  it 'returns the last url' do
    expect(error.url).to eq 'https://www.example.org/redirect'
  end

  it 'formats a message with all urls' do
    expect(error.message)
      .to eq 'Redirect loop: https://www.example.org -> https://www.example.org/redirect.'
  end
end
