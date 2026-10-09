source "https://rubygems.org"

gemspec

# gempilot needs Ruby 4.0; tayle also runs on 3.4.10, where its rake tasks are left out.
gem "gempilot", require: false if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("4.0")
gem "irb"
gem "json", "~> 2.21" # temporary json 3.0.0 is currently breaking everything
gem "rake"
gem "rspec", git: "https://github.com/rspec/rspec.git"
gem "rubocop"
gem "rubocop-claude"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
