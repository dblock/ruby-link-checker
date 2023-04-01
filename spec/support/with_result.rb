shared_context 'with result' do
  before do
    allow(subject).to receive(:called!)
    subject.on do |event, *data|
      subject.called! event, *data
    end
    subject.on :result do |result|
      @result = result
    end
  end

  let(:result) do
    @result
  end
end
