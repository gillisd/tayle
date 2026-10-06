require "forwardable"

Watcher = Data.define(:process, :tail) do
  extend Forwardable

  delegate [:state, :foreground?, :signal] => :process

  def self.spawned_as(pid)
    process = OsProcess.new(pid:)
    tail = process.spawned_tail
    raise "mywatcher #{pid} has no tail" unless tail

    new(process:, tail:)
  end

  def tail_state
    tail.state
  end

  def kill
    [process, tail].each { it.signal(:KILL) rescue nil }
  end
end
