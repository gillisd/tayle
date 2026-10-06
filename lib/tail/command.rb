class Tail
  POSITIONS = [:start, :end].freeze
  private_constant :POSITIONS

  Command = Data.define(:executable, :path, :writer, :position) do
    def initialize(executable:, path:, writer:, position:)
      unless POSITIONS.include?(position)
        raise ArgumentError, "position: must be :start or :end, not #{position.inspect}"
      end

      super(executable:, path: Pathname(path), writer:, position:)
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

    def first_byte
      case position
      in :start then 1
      in :end then path.size?.to_i + 1
      end
    end
  end
  private_constant :Command
end
