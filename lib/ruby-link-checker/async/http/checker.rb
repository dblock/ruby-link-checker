module LinkChecker
  module Async
    module HTTP
      class Task < ::LinkChecker::Task
        def run!
          checker._queue(delay: delay, host: checker._host_key(uri)) { _run! }
        end

        private

        def _run!
          client = checker._client_for(uri)
          headers = ::Protocol::HTTP::Headers[
            checker.request_headers_for(uri).map { |key, value| [key.downcase, value] }
          ]
          request = ::Protocol::HTTP::Request[method, uri.request_uri, headers]
          response = _call(client, request)
          result! Result.new(uri, method, original_uri, request, response, options)
        rescue StandardError => e
          result! ResultError.new(uri, method, original_uri, e, options)
        ensure
          response&.close
        end

        def _call(client, request)
          if checker.read_timeout
            ::Async::Task.current.with_timeout(checker.read_timeout) { client.call(request) }
          else
            client.call(request)
          end
        end
      end

      class Checker < LinkChecker::Checker
        extend ::LinkChecker::Async::HTTP::Config

        attr_accessor(*LinkChecker::Async::HTTP::Config::ATTRIBUTES)

        def initialize(options = {})
          LinkChecker::Async::HTTP::Config::ATTRIBUTES.each do |key|
            send("#{key}=", options[key] || LinkChecker::Async::HTTP::Config.send(key))
          end
          @queue = []
          @clients = {}
          @host_semaphores = {}
          if max_concurrency && (!max_concurrency.is_a?(Integer) || max_concurrency < 1)
            raise ArgumentError, "Invalid concurrency limit: #{max_concurrency}"
          end

          super
        end

        # Runs all queued checks concurrently and blocks until they complete.
        def run
          require 'async/semaphore'

          Barrier do |barrier|
            @barrier = barrier
            @semaphore = ::Async::Semaphore.new(max_concurrency) if max_concurrency
            _flush!
          end
          _finish_run
        ensure
          @barrier = nil
          @semaphore = nil
          @host_semaphores = {}
          _close_clients!
        end

        def _queue(delay: 0, host: nil, &block)
          if @barrier
            @barrier.async do
              sleep(delay) if delay.positive?
              _with_host_limit(host) do
                host_wait = _reserve_host_slot(host)
                sleep(host_wait) if host_wait.positive?
                @semaphore ? @semaphore.acquire(&block) : block.call
              end
            end
          else
            @queue << [delay, host, block]
          end
        end

        # Returns a client for the given URI's host/port/scheme, reusing (and
        # pooling connections on) one client per endpoint across all checks.
        def _client_for(uri)
          key = [uri.scheme, uri.host, uri.port]
          @clients[key] ||= begin
            endpoint = ::Async::HTTP::Endpoint.parse(uri.to_s, timeout: open_timeout, **_endpoint_options)
            ::Async::HTTP::Client.new(endpoint)
          end
        end

        private

        # Maps the configured protocol (:http1 or :http2) to the
        # corresponding async-http protocol implementation.
        def _endpoint_options
          case protocol
          when :http1
            { protocol: ::Async::HTTP::Protocol::HTTP1 }
          when :http2
            { protocol: ::Async::HTTP::Protocol::HTTP2 }
          when nil
            {}
          else
            raise ArgumentError, "Unsupported protocol: #{protocol.inspect}, expected :http1 or :http2"
          end
        end

        def _flush!
          queue = @queue
          @queue = []
          queue.each { |delay, host, block| _queue(delay: delay, host: host, &block) }
        end

        def _with_host_limit(host, &)
          return yield unless host && max_concurrency_per_host

          (@host_semaphores[host] ||= ::Async::Semaphore.new(max_concurrency_per_host)).acquire(&)
        end

        def _close_clients!
          @clients.each_value(&:close)
          @clients = {}
        end
      end
    end
  end
end
