require "zeitwerk"

##
# Top-level namespace for the tail gem.
module Tail
  LOADER = Zeitwerk::Loader.for_gem.tap(&:setup)

  ##
  # Base error class for tail.
  class Error < StandardError; end
end
