require_relative "tail/gnu_tail"
require_relative "tail/writer"
require_relative "tail/command"

##
# Follows a file by name with GNU <tt>tail -F</tt>, so it keeps going across log rotation and
# truncation.  If this process dies without #close, +tail+ exits once nothing holds the read end
# of its pipe: at once with inotify, within 0.1s when polling.
#
# GNU tail's own limits still apply: records written to a log after it is rotated away are lost,
# and a log truncated and refilled past its old size before +tail+ notices is read from the old
# offset.
#
#   Tail.new("app.log") do |tail|
#     tail.each_line(chomp: true).lazy.map(&:upcase).each { puts it }
#   end
#
# Pass <tt>position: :start</tt> to read what the log already holds first, +writer_pid+ to stop
# when the process writing it does, and +tail_path+ to run a +tail+ other than the first on +PATH+:
#
#   writer_pid = Integer(Pathname("app.pid").read)
#   Tail.new("app.log", position: :start, writer_pid:, tail_path: "/opt/coreutils/bin/tail") do |tail|
#     tail.each { print it }
#   end
class Tail
  include Enumerable

  ##
  # Raised by Tail.new unless +tail_path+ names an executable GNU coreutils +tail+ 8.28 or newer,
  # the first release to exit by itself once nothing reads its output.
  class Unsupported < StandardError
  end

  ##
  # Raised by #each if +tail+ stops for any reason but its writer exiting: killed, say, or failed.
  class Exited < StandardError
    ##
    # The Process::Status of +tail+, or +nil+ if something else reaped it first.
    attr_reader :status

    def initialize(status:)
      @status = status
      super("tail exited: #{status || "unknown status"}")
    end
  end

  ##
  # The number of lines #each has yielded, across every call; still readable after #close.
  attr_reader :lines_read

  ##
  # Follows +path+ (a String or Pathname) from its current end, so only what is appended from now
  # on is yielded; <tt>position: :start</tt> yields what is already there first.  A missing +path+
  # is read from its first byte once it appears, though GNU tail then polls instead of using
  # inotify.
  #
  # With +writer_pid+, <tt>tail --pid</tt> exits within 0.1s of that process being reaped (an
  # unreaped zombie still counts as alive), after one last read, and #each returns.
  #
  # +tail_path+ (a String or Pathname) names the +tail+ to run: a path if it contains a slash,
  # otherwise a command looked up on +PATH+.  Raises Unsupported unless that is an executable GNU
  # coreutils +tail+ 8.28 or newer.
  #
  # With a block, yields the Tail and closes it when the block exits.
  def initialize(path, writer_pid: nil, tail_path: "tail", position: :end, &block)
    @writer = writer_pid&.then { Writer.new(pid: it) }
    @lines_read = 0
    @owner_pid = Process.pid
    gnu_tail = GnuTail.locate(tail_path)
    command = Command.new(executable: gnu_tail.executable, path:, writer: @writer, position:)
    @pipe = IO.popen(command.argv)
    yield_and_close(&block) if block
  end

  ##
  # Yields each line as it is appended, blocking until the next one arrives; +chomp+ strips the
  # line ending.  Returns an Enumerator without a block, or +self+ once +tail+ exits after the
  # writer has; raises Exited if +tail+ stops any other way.  As with any IO, #close from another
  # thread raises IOError in the thread iterating.
  def each(chomp: false)
    return enum_for(__method__, chomp:) unless block_given?

    @pipe.each_line(chomp:) do |line|
      @lines_read += 1
      yield line
    end
    @pipe.close
    raise Exited.new(status: Process.last_status) unless @writer&.gone?

    self
  end
  alias each_line each

  ##
  # Kills +tail+ with SIGKILL, which it cannot ignore, and reaps it; in a forked child, only drops
  # the child's copy of the pipe.  Safe to call more than once.
  def close
    return if @pipe.closed?

    Process.kill(:KILL, @pipe.pid) if Process.pid == @owner_pid
    @pipe.close
  end

  private

  def yield_and_close
    begin
      yield self
    ensure
      close
    end
  end
end
