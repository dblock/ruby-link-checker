shared_context 'a link checker' do
  subject do
    described_class.new(user_agent: 'user/agent')
  end

  it 'updates user-agent' do
    expect(subject.user_agent).to eq 'user/agent'
  end

  context 'GET' do
    subject do
      described_class.new(methods: ['GET'])
    end

    context 'a valid URI that returns a 200', vcr: { cassette_name: '200' } do
      let(:url) { 'https://www.example.org' }
      let(:result) { subject.check!(url) }

      it 'succeeds' do
        expect(result.success?).to be true
        expect(result.error?).to be false
        expect(result.failure?).to be false
        expect(result.uri).to eq URI(url)
      end

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
        end

        it 'calls back on success' do
          expect(result.success?).to be true
          expect(subject).to have_received(:called!).with(:success)
        end
      end
    end

    context 'a valid URI that returns a 404', vcr: { cassette_name: '404' } do
      let(:url) { 'https://www.example.org/does-not-exist.html' }
      let(:result) { subject.check!(url) }

      it 'fails' do
        expect(result.success?).to be false
        expect(result.error?).to be false
        expect(result.failure?).to be true
        expect(result.uri).to eq URI(url)
        expect(result.response.code.to_i).to eq 404
      end

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
        end

        it 'calls back on success' do
          expect(result.success?).to be false
          expect(result.failure?).to be true
          expect(subject).to have_received(:called!).with(:failure)
        end
      end
    end

    context 'a redirect on HEAD followed by a 403', vcr: { cassette_name: '301+403' } do
      let(:url) { 'https://appbase.io' }
      let(:result) { subject.check!(url) }

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
          subject.on :redirect do
            subject.called!(:redirect)
          end
        end

        it 'calls redirect callback' do
          expect(result.success?).to be false
          expect(result.failure?).to be true
          expect(subject).to have_received(:called!).with(:redirect)
          expect(subject).to have_received(:called!).with(:failure)
          expect(subject).not_to have_received(:called!).with(:success)
        end
      end
    end

    context 'a redirect on HEAD followed by a 200', vcr: { cassette_name: '301+200' } do
      let(:url) { 'https://dblock.org' }
      let(:result) { subject.check!(url) }

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
          subject.on :redirect do
            subject.called!(:redirect)
          end
        end

        it 'calls redirect callback' do
          expect(result.success?).to be true
          expect(result.failure?).to be false
          expect(result.redirect?).to be false
          expect(subject).to have_received(:called!).with(:redirect)
          expect(subject).to have_received(:called!).with(:success)
          expect(subject).not_to have_received(:called!).with(:failure)
        end
      end
    end

    context 'an infinite redirect loop', vcr: { cassette_name: '301+301' } do
      let(:url) { 'https://example.org' }
      let(:result) { subject.check!(url) }

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
          subject.on :redirect do
            subject.called!(:redirect)
          end
        end

        it 'calls redirect callback' do
          expect(result.success?).to be false
          expect(result.failure?).to be false
          expect(result.error?).to be true
          expect(result.redirect?).to be false
          expect(subject).to have_received(:called!).with(:redirect).twice
          expect(subject).to have_received(:called!).with(:error)
          expect(subject).not_to have_received(:called!).with(:failure)
          expect(subject).not_to have_received(:called!).with(:success)
        end
      end
    end

    context 'an invalid URI' do
      let(:url) { '\/invalid-url' }
      let(:result) { subject.check!(url) }

      it 'fails' do
        expect(result.success?).to be false
        expect(result.failure?).to be false
        expect(result.error?).to be true
        expect(result.uri).to eq url
      end

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
        end

        it 'calls back on error' do
          expect(result.success?).to be false
          expect(subject).to have_received(:called!).with(:error)
          expect(subject).not_to have_received(:called!).with(:failure)
          expect(subject).not_to have_received(:called!).with(:success)
        end
      end
    end
  end

  context 'HEAD,GET' do
    subject do
      described_class.new(methods: %w[HEAD GET])
    end

    context 'a valid URI that fails on HEAD and succeeds on GET', vcr: { cassette_name: '404+200' } do
      let(:url) { 'https://www.example.org/packages/' }
      let(:result) { subject.check!(url) }

      it 'succeeds' do
        expect(result.success?).to be true
        expect(result.error?).to be false
        expect(result.failure?).to be false
        expect(result.uri).to eq URI(url)
      end

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
        end

        it 'does not call a failure callback' do
          expect(result.success?).to be true
          expect(result.failure?).to be false
          expect(subject).to have_received(:called!).with(:success)
          expect(subject).not_to have_received(:called!).with(:failure)
        end
      end
    end

    context 'a valid URI that fails both on HEAD and GET', vcr: { cassette_name: '404+404' } do
      let(:url) { 'https://www.example.org/packages/' }
      let(:result) { subject.check!(url) }

      it 'fails' do
        expect(result.success?).to be false
        expect(result.error?).to be false
        expect(result.failure?).to be true
        expect(result.uri).to eq URI(url)
        expect(result.response.code.to_i).to eq 404
      end

      context 'with callbacks' do
        before do
          allow(subject).to receive(:called!)
          subject.on :success do
            subject.called!(:success)
          end
          subject.on :failure do
            subject.called!(:failure)
          end
          subject.on :error do
            subject.called!(:error)
          end
        end

        it 'calls back on failure once' do
          expect(result.success?).to be false
          expect(result.failure?).to be true
          expect(subject).to have_received(:called!).with(:failure).once
        end
      end
    end
  end
end
