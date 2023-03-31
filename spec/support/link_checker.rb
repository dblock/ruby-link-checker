shared_context 'a link checker' do
  subject do
    described_class.new(user_agent: 'user/agent')
  end

  it 'updates user-agent' do
    expect(subject.user_agent).to eq 'user/agent'
  end

  context 'check' do
    let(:url) { 'https://www.example.org' }
    let(:result) do
      @result
    end

    before do
      allow(subject).to receive(:called!)
      subject.on do |event, *data|
        subject.called! event, *data
      end
      subject.on :result do |result|
        @result = result
      end
    end

    before do
      subject.check(url)
    end

    context 'GET' do
      subject do
        described_class.new(methods: ['GET'])
      end

      context 'check' do
        context 'a valid URI that returns a 200', vcr: { cassette_name: '200' } do
          it 'sets user agent' do
            expect(result.request_headers['User-Agent']).to eq "Ruby Link Checker/#{LinkChecker::VERSION}"
          end

          it 'succeeds' do
            expect(result.success?).to be true
            expect(result.error?).to be false
            expect(result.failure?).to be false
            expect(result.uri).to eq URI(url)
            expect(subject).to have_received(:called!).with(:result, result)
            expect(subject).to have_received(:called!).with(:success, result)
          end
        end

        context 'a valid URI that returns a 404', vcr: { cassette_name: '404' } do
          it 'fails' do
            expect(result.success?).to be false
            expect(result.error?).to be false
            expect(result.failure?).to be true
            expect(result.uri).to eq URI(url)
            expect(result.response.code.to_i).to eq 404
            expect(subject).to have_received(:called!).with(:failure, result)
          end
        end

        context 'a redirect on HEAD followed by a 403', vcr: { cassette_name: '301+403' } do
          it 'calls redirect callback' do
            expect(result.success?).to be false
            expect(result.failure?).to be true
            expect(subject).to have_received(:called!).with(:redirect, anything)
            expect(subject).to have_received(:called!).with(:failure, result).once
          end
        end

        context 'a redirect on HEAD followed by a 200', vcr: { cassette_name: '301+200' } do
          it 'calls redirect callback' do
            expect(result.success?).to be true
            expect(result.failure?).to be false
            expect(result.redirect?).to be false
            expect(subject).to have_received(:called!).with(:redirect, anything)
            expect(subject).to have_received(:called!).with(:success, result)
            expect(subject).not_to have_received(:called!).with(:failure, anything)
          end
        end

        context 'a redirect loop', vcr: { cassette_name: '301+301' } do
          it 'calls redirect callback' do
            expect(result.success?).to be false
            expect(result.failure?).to be false
            expect(result.error?).to be true
            expect(result.error).to be_a LinkChecker::Errors::RedirectLoopError
            expect(result.redirect?).to be false
            expect(subject).to have_received(:called!).with(:redirect, anything).twice
            expect(subject).to have_received(:called!).with(:error, result)
            expect(subject).not_to have_received(:called!).with(:failure, result)
            expect(subject).not_to have_received(:called!).with(:success, result)
          end
        end

        context 'an invalid URI' do
          let(:url) { '\/invalid-url' }

          it 'fails' do
            expect(result.success?).to be false
            expect(result.failure?).to be false
            expect(result.error?).to be true
            expect(result.uri).to eq url
            expect(subject).to have_received(:called!).with(:result, result)
            expect(subject).to have_received(:called!).with(:error, result)
            expect(subject).not_to have_received(:called!).with(:failure)
            expect(subject).not_to have_received(:called!).with(:success)
          end
        end
      end

      context 'HEAD,GET' do
        subject do
          described_class.new(methods: %w[HEAD GET])
        end

        context 'a valid URI that fails on HEAD and succeeds on GET', vcr: { cassette_name: '404+200' } do
          it 'succeeds' do
            expect(result.success?).to be true
            expect(result.error?).to be false
            expect(result.failure?).to be false
            expect(result.uri).to eq URI(url)
            expect(subject).to have_received(:called!).with(:success, result)
            expect(subject).not_to have_received(:called!).with(:failure, result)
          end
        end

        context 'a valid URI that fails both on HEAD and GET', vcr: { cassette_name: '404+404' } do
          it 'fails' do
            expect(result.success?).to be false
            expect(result.error?).to be false
            expect(result.failure?).to be true
            expect(result.uri).to eq URI(url)
            expect(result.response.code.to_i).to eq 404
            expect(subject).to have_received(:called!).with(:failure, result).once
          end
        end
      end
    end
  end
end
