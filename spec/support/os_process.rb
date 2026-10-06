OsProcess = Data.define(:pid) do
  def state
    case ps(columns: "stat=").strip
    in "" | /\AZ/ then :gone
    in /\AT/ then :stopped
    else :running
    end
  end

  def foreground?
    pgid, terminal_pgid = ps(columns: "pgid=,tpgid=").split
    pgid == terminal_pgid
  end

  def spawned_tail
    parent = pid.to_s
    process_table(columns: "pid=,ppid=,args=")
      .lines
      .map(&:split)
      .find { it in [_, ^parent, %r{(?:\A|/)tail\z}, "-F", *] }
      &.then { self.class.new(pid: Integer(it.first)) }
  end

  def signal(name)
    Process.kill(name, pid)
  end

  private

  def ps(columns:)
    IO.popen(["ps", "-o", columns, "-p", pid.to_s], err: File::NULL, &:read)
  end

  def process_table(columns:)
    IO.popen(["ps", "-o", columns, "-A"], err: File::NULL, &:read)
  end
end
