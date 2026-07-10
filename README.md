# Horologium

[![Tests](https://github.com/rhannequin/horologium/workflows/CI/badge.svg)](https://github.com/rhannequin/horologium/actions?query=workflow%3ACI)

Horologium is a Ruby library dedicated to **scientific time**: the time scales
(UTC, TAI, TT, TDB, TCG, TCB, UT1, GPS), high-precision instants, Julian Dates,
intervals, and rigorous conversions between scales that astronomy and physics
require.

## Installation

Install the gem and add it to the application's Gemfile by running:

```sh
bundle add horologium
```

Or install it directly:

```sh
gem install horologium
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake` to run the tests and RuboCop, or `rake steep` to type-check the
signatures in `sig/`. Run `COVERAGE=true rake test` to measure test coverage,
which is enforced at a 95% line minimum in CI. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

Run `bin/ci` to run every check that GitHub Actions runs (RuboCop, Steep, YARD
documentation coverage, and the tests with coverage) in a single pass. It runs
each check even when an earlier one fails, so you see everything that needs
fixing at once.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and the created tag, and push the `.gem` file to [rubygems.org].

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/rhannequin/horologium.

## License

The gem is available as open source under the terms of the [MIT License].

## Code of Conduct

Everyone interacting in the Horologium project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow the [code of conduct].

[rubygems.org]: https://rubygems.org
[MIT License]: https://opensource.org/licenses/MIT
[code of conduct]: https://github.com/rhannequin/horologium/blob/main/CODE_OF_CONDUCT.md
