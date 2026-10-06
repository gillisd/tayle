require "bundler/gem_tasks"

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

require "gempilot/version_task"
Gempilot::VersionTask.new

require "gempilot/zeitwerk_task"
Gempilot::ZeitwerkTask.new

task default: [:spec, :rubocop]
