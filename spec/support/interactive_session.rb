require "pty"

class InteractiveSession
  PROMPT = "tail-spec$ ".freeze
  SHELL = ["bash", "--norc", "--noprofile", "-i"].freeze

  attr_reader :watcher

  def initialize(env:, dir:)
    @output = SessionOutput.new
    @reader, @writer, @pid = PTY.spawn(env.merge("PS1" => PROMPT, "TERM" => "dumb"), *SHELL, chdir: dir)
    @output.pump(@reader)
    @output.await(PROMPT)
  end

  def start(command)
    since = @output.mark
    type(command)
    @watcher = @output.await_watcher(since:)
  end

  def type(line)
    @writer.write("#{line}\n")
  end

  def press_ctrl_c
    press("\x03", echo: "^C")
  end

  def press_ctrl_z
    since = @output.mark
    press("\x1a", echo: "^Z")
    @output.await(/\]\+ +Stopped/, since:)
  end

  def bring_to_foreground
    type("fg")
    wait_until { watcher.foreground? }
  end

  def resume_in_background
    type("bg")
    wait_until { watcher.state == :running }
  end

  def hang_up
    [@reader, @writer].each(&:close)
    Process.wait(@pid)
  end

  def output
    @output.to_s
  end

  def close
    @watcher&.kill
    kill_shell
    [@reader, @writer].reject(&:closed?).each(&:close)
    reap_shell
  end

  private

  # The shell may have exited on its own, which is what several examples check.
  def kill_shell
    Process.kill(:KILL, @pid)
  rescue Errno::ESRCH
    nil
  end

  def reap_shell
    Process.wait(@pid)
  rescue Errno::ECHILD
    nil
  end

  def press(key, echo:)
    since = @output.mark
    @writer.write(key)
    @output.await(echo, since:)
  end

  def wait_until
    Timeout.timeout(5) { sleep 0.02 until yield }
  end
end
