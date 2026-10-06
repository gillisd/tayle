class Tail
  Writer = Data.define(:pid) do
    def initialize(pid:)
      super(pid: Integer(pid))
    end

    def flag
      "--pid=#{pid}"
    end

    def gone?
      begin
        Process.kill(0, pid)
        false
      rescue Errno::EPERM
        false
      rescue Errno::ESRCH
        true
      end
    end
  end
  private_constant :Writer
end
