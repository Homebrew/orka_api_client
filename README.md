# orka_api_client

This is a Ruby library for interacting with MacStadium's [Orka](https://www.macstadium.com/orka) API.

⚠️⚠️⚠️ **This gem is largely untested beyond basic read-only operations. API stability is not guaranteed at this time.** ⚠️⚠️⚠️

## Installation

**This gem is not yet available on RubyGems.**

Add this line to your application's Gemfile:

```ruby
gem 'orka_api_client', git: "https://github.com/Homebrew/orka_api_client"
```

And then execute:

    $ bundle install

## Usage

TODO: examples

Documentation is in the `docs` folder after running `bundle exec rake yard`.

A Sorbet RBI file is available for this gem.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

RuboCop can be run via `bundle exec rake rubocop`.

## Tests

This is non-existent at the moment. Ideally this would involve a real Orka test environment, but I don't have one readily available that's not already being used for real CI.

When they exist, `bundle exec rake spec` can be used to run the tests.
