require "rbconfig"

module Mywatcher
  ROOT = Pathname(__dir__)
         .parent
         .parent
  BIN = ROOT.join("spec/fixtures/bin")
  LIB = ROOT.join("lib")

  def self.env
    {
      "PATH" => [BIN, RbConfig::CONFIG["bindir"], ENV.fetch("PATH")].join(File::PATH_SEPARATOR),
      "RUBYLIB" => LIB.to_s,
      "RUBYOPT" => nil,
    }
  end
end
