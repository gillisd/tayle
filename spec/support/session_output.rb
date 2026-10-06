class SessionOutput
  READY = /mywatcher (\d+) following/

  def initialize
    @text = String.new(encoding: Encoding::BINARY)
    @lock = Mutex.new
  end

  def pump(io)
    Thread.new do
      begin
        loop { append(io.readpartial(4096)) }
      rescue IOError, Errno::EIO
        nil
      end
    end
  end

  def to_s
    @lock.synchronize { @text.dup }
  end

  def mark
    @lock.synchronize { @text.bytesize }
  end

  def await_watcher(since: 0)
    Watcher.spawned_as(Integer(await(READY, since:)[1]))
  end

  def await(pattern, since: 0, within: 5)
    deadline = now + within
    loop do
      match = read_since(since).match(Regexp.union(pattern))
      return match if match
      raise "no #{pattern.inspect} in #{read_since(since).inspect}" if now > deadline

      sleep 0.02
    end
  end

  private

  def append(chunk)
    @lock.synchronize { @text << chunk.b }
  end

  def read_since(mark)
    to_s.byteslice(mark..)
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
