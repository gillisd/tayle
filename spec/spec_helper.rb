require "timeout"
require "tmpdir"
require "tail"
require_relative "support/eventually"
require_relative "support/eventually_helper"
require_relative "support/process_probe"
require_relative "support/os_process"
require_relative "support/watcher"
require_relative "support/session_output"
require_relative "support/interactive_session"
require_relative "support/detached_session"
require_relative "support/mywatcher"
require_relative "support/scratch_directory"

RSpec.configure do |config|
  config.include EventuallyHelper
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.default_formatter = config.files_to_run.one? ? "doc" : "progress"
  config.define_derived_metadata { it[:aggregate_failures] = it.fetch(:aggregate_failures, true) }
  config.around { |example| Timeout.timeout(10) { example.run } }
end
