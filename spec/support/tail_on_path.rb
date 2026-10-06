RSpec.shared_context "with a tail on PATH reporting" do |banner|
  around do |example|
    original = ENV.fetch("PATH")
    begin
      ENV.store("PATH", "#{dir}:#{original}")
      example.run
    ensure
      ENV.store("PATH", original)
    end
  end

  before do
    impostor = dir.join("tail")
    impostor.write("#!/bin/sh\necho '#{banner}'\n")
    impostor.chmod(0o755)
  end
end
