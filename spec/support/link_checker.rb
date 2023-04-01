shared_context 'a link checker' do
  context 'user-agent' do
    subject do
      described_class.new(user_agent: 'user/agent')
    end

    it 'updates user-agent' do
      expect(subject.user_agent).to eq 'user/agent'
    end
  end

  context 'check' do
    let(:url) { 'https://www.example.org' }

    include_context 'with result'

    context 'with metadata' do
      before do
        subject.check(url, foo: 'bar')
      end

      context 'GET' do
        subject do
          described_class.new(methods: ['GET'])
        end

        context 'check' do
          context 'a valid URI that returns a 200', vcr: { cassette_name: '200' } do
            it 'passes metadata' do
              expect(result.options).to eq(foo: 'bar')
            end
          end
        end
      end
    end

    context 'without results' do
      before do
        subject.check(url, foo: 'bar')
      end

      context 'GET' do
        subject do
          described_class.new(results: false, methods: ['GET'])
        end

        context 'check' do
          context 'a valid URI that returns a 200', vcr: { cassette_name: '200' } do
            it 'passes metadata' do
              expect(subject.results).to be_nil
            end
          end
        end
      end
    end

    context 'without metadata' do
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

            it 'returns all metadata' do
              expect(result.options).to eq({})
            end

            it 'returns results' do
              expect(subject.results).to eq(
                error: [],
                failure: [],
                success: [
                  result
                ]
              )
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

          context 'a 404', vcr: { cassette_name: '404', allow_playback_repeats: true } do
            it 'fails' do
              expect(result.success?).to be false
              expect(result.error?).to be false
              expect(result.failure?).to be true
              expect(result.uri).to eq URI(url)
              expect(result.response.code.to_i).to eq 404
              expect(subject).to have_received(:called!).with(:failure, result)
            end

            context 'with 0 retries' do
              subject do
                described_class.new(methods: ['GET'], retries: 0)
              end

              it 'fails' do
                expect(result.success?).to be false
                expect(result.error?).to be false
                expect(result.failure?).to be true
                expect(result.uri).to eq URI(url)
                expect(result.response.code.to_i).to eq 404
                expect(subject).to have_received(:called!).with(:failure, result).once
                expect(subject).not_to have_received(:called!).with(:retry, anything)
              end
            end

            context 'with 1 retry' do
              subject do
                described_class.new(methods: ['GET'], retries: 1)
              end

              it 'fails' do
                expect(result.success?).to be false
                expect(result.error?).to be false
                expect(result.failure?).to be true
                expect(result.uri).to eq URI(url)
                expect(result.response.code.to_i).to eq 404
                expect(subject).to have_received(:called!).with(:failure, result).once
                expect(subject).to have_received(:called!).with(:retry, anything).once
              end
            end

            context 'with 2 retries' do
              subject do
                described_class.new(methods: ['GET'], retries: 2)
              end

              it 'fails' do
                expect(result.success?).to be false
                expect(result.error?).to be false
                expect(result.failure?).to be true
                expect(result.uri).to eq URI(url)
                expect(result.response.code.to_i).to eq 404
                expect(subject).to have_received(:called!).with(:failure, result).once
                expect(subject).to have_received(:called!).with(:retry, anything).twice
              end
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

          context 'a retry on 429', vcr: {
            cassette_name: '429+200',
            match_requests_on: [lambda { |_request, recorded_request|
              @matched ||= []
              if @matched.size + 1 === recorded_request.headers['Index'].first
                @matched << recorded_request
                true
              else
                false
              end
            }]
          } do
            subject do
              described_class.new(methods: ['GET'], retries: 1)
            end

            it 'calls a retry callback' do
              expect(result.success?).to be true
              expect(result.failure?).to be false
              expect(result.redirect?).to be false
              expect(subject).to have_received(:called!).with(:retry, anything)
              expect(subject).to have_received(:called!).with(:success, result)
              expect(subject).not_to have_received(:called!).with(:failure, anything)
              expect(subject).not_to have_received(:called!).with(:error, anything)
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
end
