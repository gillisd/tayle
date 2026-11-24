class Tayle
  POSITIONS = [:start, :end].freeze
  private_constant :POSITIONS

  Command = Data.define(:executable, :path, :writer, :position) do
    def initialize(executable:, path:, writer:, position:)
      path = Pathname(path)
      check_position(position, path:)
      super
    end

    def argv
      [
        executable.to_s,
        "-F",
        "--sleep-interval=0.1",
        *writer&.flag,
        "--bytes=+#{first_byte}",
        "--",
        path.to_s,
      ]
    end

    private

    ##
    # tail reads a file shorter than the offset as truncated, from its first byte, so an offset
    # past the end (a missing path being 0 bytes long) is refused here.
    def check_position(position, path:)
      unless POSITIONS.include?(position) || (position.is_a?(Integer) && !position.negative?)
        raise ArgumentError, "position: must be :start, :end or a non-negative byte offset, not #{position.inspect}"
      end
      return unless position.is_a?(Integer) && position > (size = path.size?.to_i)

      raise ArgumentError, "position: byte offset #{position} is past the end of #{path} (#{size} bytes)"
    end

    def first_byte
      case position
      in :start then 1
      in :end then path.size?.to_i + 1
      in Integer => offset then offset + 1
      end
    end
  end
  private_constant :Command
end
