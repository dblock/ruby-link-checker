shared_context 'with url' do
  subject do
    described_class.new(methods: ['GET'])
  end

  let(:url) { 'https://www.example.org' }

  include_context 'with result'

  before do
    subject.check(url)
  end
end
