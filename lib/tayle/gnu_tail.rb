class Tayle
  OLDEST_SUPPORTED_VERSION = [8, 28].freeze
  private_constant :OLDEST_SUPPORTED_VERSION

  GnuTail = Data.define(:executable, :version) do
    def self.locate(command)
      executable = list_candidates(command).find { it.file? && it.executable? }
      raise Unsupported, "#{command} not found or not executable" unless executable

      new(executable:, version: read_version(executable)).tap(&:check_supported)
    end

    def self.list_candidates(command)
      return [Pathname(command)] if command.to_s.include?("/")

      ENV
        .fetch("PATH", "")
        .split(File::PATH_SEPARATOR)
        .map { Pathname(it).join(command) }
    end

    def self.read_version(executable)
      IO.popen([executable.to_s, "--version"], err: File::NULL, &:read)
        .match(/\Atail \(GNU coreutils\) (\d+)\.(\d+)/)
        &.then { [Integer(it[1]), Integer(it[2])] }
    end
    private_class_method :list_candidates, :read_version

    def check_supported
      raise Unsupported, "#{executable} is not GNU coreutils tail" unless version
      return unless (version <=> OLDEST_SUPPORTED_VERSION).negative?

      raise Unsupported, "#{executable} is GNU coreutils tail #{version.join(".")}; Tayle needs 8.28 or newer"
    end
  end
  private_constant :GnuTail
end
