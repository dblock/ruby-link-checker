# frozen_string_literal: true

require 'socket'

# A local HTTP/1.1 server that answers every request with 200 after a delay,
# recording request start times and the most requests in flight at once.
class HostServer
  attr_reader :port, :max_active, :starts

  def initialize(delay: 0.05)
    @delay = delay
    @server = TCPServer.new('127.0.0.1', 0)
    @port = @server.addr[1]
    @mutex = Mutex.new
    @active = 0
    @max_active = 0
    @starts = []
    @thread = Thread.new { accept }
  end

  def url(path)
    "http://127.0.0.1:#{port}#{path}"
  end

  def stop
    @server.close
    @thread.join
  end

  private

  def accept
    loop { Thread.new(@server.accept) { |client| handle(client) } }
  rescue IOError, Errno::EBADF
    nil
  end

  def handle(client)
    nil while (line = client.gets) && line != "\r\n"
    track { sleep(@delay) }
    client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
  rescue IOError, SystemCallError
    nil
  ensure
    client.close
  end

  def track
    @mutex.synchronize do
      @starts << Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @active += 1
      @max_active = [@max_active, @active].max
    end
    yield
  ensure
    @mutex.synchronize { @active -= 1 }
  end
end
