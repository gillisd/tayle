# Tayle

Follow a file by name with GNU tail -F, across rotation and truncation

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add tayle

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install tayle

## Usage

`Tayle.new` follows a file by name, so it keeps going across log rotation and
truncation. Reading starts at the current end of the file:

```ruby
Tayle.new("app.log") do |tayle|
  tayle.each_line(chomp: true).lazy.map(&:upcase).each { puts it }
end
```

Pass `position: :start` to read what the log already holds first, `writer_pid:`
to stop once the process writing it does, and `tail_path:` to run a `tail`
other than the first on `PATH`. See the rdoc on `Tayle` for the details.

Requires GNU coreutils `tail` 8.28 or newer; anything else raises
`Tayle::Unsupported`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake` to run the specs and RuboCop.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
