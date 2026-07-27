# Horologium

[![Tests](https://github.com/rhannequin/horologium/workflows/CI/badge.svg)](https://github.com/rhannequin/horologium/actions?query=workflow%3ACI)

Horologium is a Ruby library dedicated to **scientific time**: the time scales
(UTC, TAI, TT, TDB, TCG, TCB, UT1, GPS), high-precision instants, Julian Dates,
intervals, and rigorous conversions between scales that astronomy and physics
require.

Ruby already has `Time`, `Date`, `DateTime`, and `ActiveSupport` for civil time:
time zones, calendars, human formatting. None of them knows the difference
between UTC and a continuous scale, the TAI, TT, and TDB scales an ephemeris
needs, or a Julian Date kept precise to the nanosecond. That is the gap
Horologium fills.

## Content

- [Installation](#installation)
- [Usage](#usage)
- [Precision](#precision)
- [Status](#status)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)
- [Code of Conduct](#code-of-conduct)

## Installation

Install the gem and add it to the application's Gemfile by executing:

    $ bundle add horologium

If [Bundler] is not being used to manage dependencies, install the gem by
executing:

    $ gem install horologium

## Usage

An `Instant` is a single point on the timeline, kept internally as a TAI Julian
Date. A `Duration` is an amount of time in SI seconds, with no date and no scale
attached. You shift an instant by a duration, and you subtract two instants to
get the duration between them.

```rb
require "horologium"

a = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
b = Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)

a + Horologium::Duration.days(1) == b        # => true
a < b                                        # => true
b - a == Horologium::Duration.days(1)        # => true
```

An instant has no scale of its own. You give it a Julian Date read in a scale,
and you read it back in any scale the library knows: `to` chooses the scale, and
`as` chooses the shape it comes out in.

```rb
instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

instant.to(:tt).as(:julian_date)               # => 2443144.5003725
instant.as(:modified_julian_date, scale: :tt)  # => 43144.0003725
```

A calendar date is a shape too, and the one a person reads. It comes out as a
`CivilTime`, whose fields are the ones a clock and a calendar show, in the
proleptic Gregorian calendar.

```rb
civil = instant.as(:civil, scale: :tt)

civil.year    # => 1977
civil.month   # => 1
civil.second  # => 32
```

You can build an instant from those fields as well, and nothing is lost on the
way in: the date becomes a whole number of days and the time of day an exact
fraction of one. Give a fractional second as a `Rational` to say it exactly.

```rb
Horologium::Instant.from_civil(2025, 5, 1, 12, 0, 0, scale: :tt)
Horologium::Instant.from_civil(2025, 5, 1, 12, 0, Rational(1, 4), scale: :tt)
```

Each scale has its own shortcut, so the scale is in the name instead of a
keyword.

```rb
Horologium::Instant.from_tt(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tai(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tdb(2025, 5, 1, 12, 0, 0)
```

A date that does not exist is refused rather than rolled over, and the message
says which field is wrong.

```rb
Horologium::Instant.from_civil(1900, 2, 29, scale: :tt)
# => raises Horologium::InvalidCivilTimeError
```

The same date and time write out as an extended ISO 8601 string, and read back
from one. The scale is not written into the string: there is no ISO 8601
designator for TAI or TT, and `Z` means UTC, so a bare time is a coordinate in
the scale you asked for.

```rb
instant.as(:iso8601, scale: :tt)   # => "1977-01-01T00:00:32.184000000"

Horologium::Instant.from_iso8601("2025-05-01T12:00:00", scale: :tt)
Horologium::Instant.from_iso8601("2025-05-01", scale: :tt)  # midnight
```

The parser reads a strict subset: a calendar date, an optional time of day
after a `T`, a fraction of a second kept to every digit, and an optional `Z` or
numeric offset applied as plain arithmetic, not a time zone. A week date, an
ordinal date, or anything outside the subset is refused with a `ParseError`.

UTC is the scale of civil clocks, the one that holds a leap second now and
then to keep step with the Earth's rotation. `from_utc` reads a UTC date, and
a leap second is a legal reading: the second is 60 on a day that holds one, and
that moment really existed.

```rb
Horologium::Instant.from_utc(2025, 5, 1, 12, 0, 0)

leap = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)
leap.as(:iso8601, scale: :utc)  # => "2016-12-31T23:59:60.000000000Z"
```

A leap second is a real second on the timeline, so the arithmetic is right
across it: the second before 23:59:60, the leap second, and the next midnight
are one SI second apart each. Second 60 on a day with no leap second is
refused.

```rb
before = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 59)
before + Horologium::Duration.seconds(1) ==
  Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)  # => true

Horologium::Instant.from_utc(2020, 6, 15, 23, 59, 60)
# => raises Horologium::InvalidCivilTimeError
```

UTC runs from 1972, where it settled into whole leap seconds. An earlier UTC
date raises `Horologium::OutOfRangeError`. The instant is still reachable, only
its UTC label is not, so the error names the continuous scales, which have no
lower bound. The leap seconds come from the [iers] gem, with no network access:
the data ships with the gem.

```rb
Horologium::Instant.from_utc(1971, 12, 31)                  # => OutOfRangeError
Horologium::Instant.from_civil(1971, 12, 31, scale: :tt)    # reaches any date
```

Leap seconds are announced about six months ahead, so past the date its data
vouches for, the last known offset is the best there is. A UTC reading says
which it rests on: `:measured` up to that date, `:extrapolated` after, where a
leap second announced since would not be known.

```rb
instant.to(:utc).provenance   # => :measured, or :extrapolated past the horizon
```

A pipeline that must not rest on an offset a leap second could overturn sets a
strict horizon, and a reading past it raises instead.

```rb
Horologium.configure { |c| c.leap_second_horizon = :raise }
# => reading a date past the data horizon raises OutOfDataRangeError
```

A Julian Date is around 2.46 million, which leaves a single `Float` about 40
microseconds for the fraction of a day, and the loss is already in the literal
before Horologium sees it. So the lossless shapes come first: a `String` and a
`Rational` say the Julian Date exactly, and a high and a low part say it to
about twice what one `Float` holds.

```rb
Horologium::Instant.from_julian_date("2456463.052272", scale: :tt)
Horologium::Instant.from_julian_date(
  Rational(2_456_463_052_272, 1_000_000),
  scale: :tt
)
Horologium::Instant.from_julian_date(2_456_463.0, 0.052272, scale: :tt)

Horologium::Instant.from_modified_julian_date(60_796.0, scale: :tai)
```

A `Duration` counts SI seconds, so `Duration.days(1)` is always 86,400 SI
seconds. Because of leap seconds a civil day can be a second longer or shorter,
so a duration and a calendar day are different things.

```rb
Horologium::Duration.days(1) == Horologium::Duration.seconds(86_400)  # => true
Horologium::Duration.nanoseconds(1_000_000_000) ==
  Horologium::Duration.seconds(1)                                     # => true
```

Adding a duration to an instant makes sense, but adding two instants together
does not, so it raises an error.

```rb
instant + instant  # => raises Horologium::DimensionalError
```

Exact equality is rarely what scientific code wants, so you can compare within a
tolerance:

```rb
a = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
near = a + Horologium::Duration.nanoseconds(1)

a.equal_within?(near, Horologium::Duration.nanoseconds(2))  # => true
```

## Precision

A modern Julian Date is around 2.46 million. A single `Float` spends most of its
digits on that large number and has only tens of microseconds left for the
fraction of a day. That is too coarse for scientific time. Horologium stores an
instant across two `Float`s whose sum is the Julian Date, so the second one
starts where the first runs out of digits. This is the representation [ERFA]
uses, it keeps the precision below a nanosecond for any date, and it does so
with ordinary floating-point arithmetic.

Every value carries one of two precisions, fixed when it is built:

- `:standard`, the default, keeps the value as a two-part float. It is fast and
  stays within a few nanoseconds of the true value.
- `:exact` keeps the value as a `Rational`, with no rounding. The test suite
  uses it to check that `:standard` stays within its stated precision.

Set the default once at boot:

```rb
Horologium.configure do |c|
  c.default_precision = :exact
end
```

Choose it for a single value, or for a scoped block:

```rb
Horologium::Instant.from_julian_date(
  2_460_000.5,
  scale: :tai,
  precision: :exact
)

Horologium.with_precision(:exact) do
  # instants and durations built here default to :exact
end
```

Exactness is contagious. An operation between two `:standard` values stays
`:standard`. Mixing a `:standard` and an `:exact` value gives an `:exact`
result, so precision is not quietly lost. `:exact` guarantees the arithmetic
Horologium performs. It cannot bring back precision that an input already lost
when it was built.

## Status

This library is in early development, before its first public release. The
public API is not stable, so new versions will probably introduce breaking
changes until a 1.0 release. Changes are documented in the [CHANGELOG].

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

[Bundler]: https://bundler.io
[ERFA]: https://github.com/liberfa/erfa
[CHANGELOG]: https://github.com/rhannequin/horologium/blob/main/CHANGELOG.md
[rubygems.org]: https://rubygems.org
[MIT License]: https://opensource.org/licenses/MIT
[code of conduct]: https://github.com/rhannequin/horologium/blob/main/CODE_OF_CONDUCT.md
