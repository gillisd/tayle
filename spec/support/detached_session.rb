class DetachedSession
  attr_reader :watcher

  def initialize(env:, dir:)
    @env = env
    @dir = dir
    @output = SessionOutput.new
  end

  def start(command)
    reader, writer = IO.pipe
    @pid = fork do
      Process.setsid
      exec(@env, "/bin/sh", "-c", command, chdir: @dir, in: File::NULL, out: writer, err: writer)
    end
    writer.close
    Process.detach(@pid)
    @output.pump(reader)
    @watcher = @output.await_watcher
  end

  def press_ctrl_c
    signal_group(:INT)
  end

  def signal_group(signal)
    Process.kill(signal, -@pid)
  end

  def output
    @output.to_s
  end

  def close
    @watcher&.kill
    signal_group(:KILL) rescue nil
  end
end
