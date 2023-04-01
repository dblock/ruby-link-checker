# frozen_string_literal: true

require 'spec_helper'

describe LinkChecker::Callbacks do
  subject do
    Class.new do
      include LinkChecker::Callbacks
    end.new
  end

  context 'one callback' do
    before do
      allow(subject).to receive(:called!)
      subject.on :foo do |data|
        subject.called! data
      end
    end

    it 'invokes callback' do
      2.times { subject.send(:callback, :foo, :foo) }
      2.times { subject.send(:callback, :bar, :bar) }
      expect(subject).to have_received(:called!).with(:foo).twice
      expect(subject).not_to have_received(:called!).with(:bar)
    end
  end

  context 'multiple callbacks' do
    before do
      allow(subject).to receive(:called!)
      subject.on :foo, :bar do |data|
        subject.called! data
      end
    end

    it 'invokes both callbacks' do
      2.times { subject.send(:callback, :foo, :foo) }
      subject.send(:callback, :bar, :bar)
      expect(subject).to have_received(:called!).with(:foo).twice
      expect(subject).to have_received(:called!).with(:bar)
    end
  end
end
