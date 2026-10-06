class ProcessProbe
  def initialize
    @reader, @writer = IO.pipe
  end

  def watch
    original_stderr = $stderr.dup
    begin
      $stderr.reopen(@writer)
      yield
    ensure
      $stderr.reopen(original_stderr)
      [original_stderr, @writer].each(&:close)
    end
  end

  def await_warning(within: 3)
    raise "nothing on stderr within #{within}s" unless @reader.wait_readable(within)
  end

  def exited?
    @reader.timeout = 0
    begin
      @reader.read
    rescue IO::TimeoutError
      return false
    end
    true
  end
end
