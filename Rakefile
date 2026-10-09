require "bundler/gem_tasks"

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

# gempilot needs Ruby 4.0, so the Gemfile leaves it out on 3.4 and these tasks go with it.
if Gem.loaded_specs.key?("gempilot")
  require "gempilot/version_task"
  Gempilot::VersionTask.new

  require "gempilot/zeitwerk_task"
  Gempilot::ZeitwerkTask.new
end

task default: [:spec, :rubocop]
