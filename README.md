# Horologium

[![Tests](https://github.com/rhannequin/horologium/workflows/CI/badge.svg)](https://github.com/rhannequin/horologium/actions?query=workflow%3ACI)

Horologium is a Ruby library dedicated to **scientific time**: the time scales
(TAI, TT, TDB, TCG, TCB, GPS, UTC and UT1), high-precision instants, Julian
Dates, intervals, and rigorous conversions between scales that astronomy and
physics require.

Ruby already has `Time`, `Date`, `DateTime`, and `ActiveSupport` for civil time:
time zones, calendars, human formatting. None of them knows the difference
between UTC and a continuous scale, the TAI, TT, and TDB scales an ephemeris
needs, or a Julian Date kept precise to the nanosecond. That is the gap
Horologium fills.

## Content

- [Installation](#installation)
- [Usage](#usage)
- [Intervals](#intervals)
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

Ruby's own `Time` is a bridge in, and the system clock is one line. A `Time`
is read in UTC and every field it carries is used, so nothing is rounded on
the way: `subsec` is a `Rational`, not a count of nanoseconds.

```rb
Horologium::Instant.now
Horologium::Instant.from_time(Time.utc(2025, 5, 1, 12))
Horologium::Instant.from_unix(1_370_351_716.32)

Horologium::Instant.from_offset(
  Horologium::Epochs::J2000,
  Horologium::Duration.julian_centuries(0.25)
)
```

Unix time is not a count of elapsed seconds. It has no leap seconds, so it is
a way of writing a UTC date, and reaching a UTC date takes one more SI second
for every leap second inserted along the way. `from_unix(1_700_000_000)` and
`Epochs::UNIX + Duration.seconds(1_700_000_000)` are about 29 seconds apart,
and the first one is the later.

A `Time` cannot hold a leap second either. `Time.utc(2016, 12, 31, 23, 59, 60)`
is silently the first moment of 2017, because POSIX time has no leap seconds
and every day in it is 86,400 seconds long. `from_time` is exact for
everything a `Time` can carry, but a timestamp that held a second 60 lost it
before Horologium saw it; read that one with `from_utc` or `from_iso8601`.

Each scale has its own shortcut, so the scale is in the name instead of a
keyword.

```rb
Horologium::Instant.from_tt(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tai(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tdb(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tcg(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tcb(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_gps(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_ut1(2025, 5, 1, 12, 0, 0)
```

TDB is the one scale that rests on a model rather than a definition. Horologium
runs the full 787-term Fairhead and Bretagnon series, the one [ERFA] evaluates
in `dtdb`, rather than a truncation of it.

TCG and TCB are the coordinate times of the Earth-centred and barycentric
frames. Each runs ahead of the scale it is defined on at a fixed rate set by
definition, TCG on TT by about 22 milliseconds a year and TCB on TDB by about
half a second, both counted from 1977-01-01 00:00:00 TAI. GPS time is a fixed
19 SI seconds behind TAI and stays there, because it counts SI seconds and
never takes a leap second.

```rb
instant = Horologium::Instant.from_julian_date(2_451_545.0, scale: :tt)

instant.to(:tcg).as(:julian_date)  # => 2451545.0000058548
instant.to(:tcb).as(:julian_date)  # => 2451545.000130251
instant.to(:gps).as(:julian_date)  # => 2451544.9994075927
```

UT1 follows the actual rotation of the Earth, which is irregular, so it is the
one scale here that is measured rather than defined. Horologium reads the
difference from the [iers] gem and converts as `UT1 = TT - delta T`, not as
`UTC + delta UT1`. That is what lets it reach back past 1961: UTC is not
defined before then and refuses the date, while delta T is estimated from a
polynomial fit as far back as 1800, so the instant still has a UT1 name.

```rb
instant = Horologium::Instant.from_ut1(1955, 1, 1, 12)

instant.as(:iso8601, scale: :tt)   # => "1955-01-01T12:00:31.047050952"
instant.as(:iso8601, scale: :utc)  # => raises OutOfRangeError
```

A UT1 reading says where its number came from, so you can tell an observation
from a prediction from a fit. It is `:measured` where the published series
observed it, `:extrapolated` where the series predicts it, and `:estimated`
where the series does not reach and the polynomial answered instead.

```rb
Horologium::Instant.from_utc(2020, 1, 1).to(:ut1).provenance  # => :measured
Horologium::Instant.from_ut1(1900, 1, 1).to(:ut1).provenance  # => :estimated
```

Past the end of the published data the last known delta T is held rather than
refused, and the reading says `:extrapolated`. Holding it is a projection, not
a bounded value: delta T follows the Earth's rotation, which drifts, and every
leap second nobody has announced yet adds a second of its own. Over the months
the data usually runs ahead it is worth milliseconds, but the error grows the
further out you go, and over years it reaches seconds. The recent drift has
been about 0.04 seconds a year, the last half century about 0.47. A pipeline
that must not compute on it turns the reading into a refusal.

```rb
Horologium.configure { |c| c.ut1_horizon = :raise }
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
before = Horologium::Instant.from_utc(
  2016, 12, 31, 23, 59, 59,
  precision: :exact
)
leap = Horologium::Instant.from_utc(
  2016, 12, 31, 23, 59, 60,
  precision: :exact
)
after = Horologium::Instant.from_utc(
  2017, 1, 1, 0, 0, 0,
  precision: :exact
)

leap - before == Horologium::Duration.seconds(1)   # => true
after - leap == Horologium::Duration.seconds(1)    # => true

Horologium::Instant.from_utc(2020, 6, 15, 23, 59, 60)
# => raises Horologium::InvalidCivilTimeError
```

The `:exact` above is what makes `==` the right question to ask. At the default
`:standard` precision the same three instants land a rounding step apart, well
under a nanosecond but not zero, so compare those with `equal_within?`.

UTC runs from 1961, whole leap seconds from 1972 and the earlier
rate-adjustment drift before that, where a UTC second was fractionally longer
than an SI one. An earlier UTC date raises `Horologium::OutOfRangeError`. The
instant is still reachable, only its UTC label is not, so the error names the
continuous scales, which have no lower bound. The leap seconds and the drift
come from the [iers] gem, with no network access: the data ships with the gem.

```rb
Horologium::Instant.from_utc(1960, 12, 31)                  # => OutOfRangeError
Horologium::Instant.from_civil(1960, 12, 31, scale: :tt)    # reaches any date
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

The configuration is set once, in a single `Horologium.configure` block, and
frozen when the block returns. See [Precision](#precision).

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

Horologium::Duration.minutes(90)
Horologium::Duration.hours(6)
Horologium::Duration.zero
```

A Julian year is exactly 365.25 days and a Julian century is 36,525 days. They
are astronomical constants. A calendar year holds 365 or 366 days, so a Julian
year lands a few hours away from the same date next year.

```rb
Horologium::Duration.julian_years(1) ==
  Horologium::Duration.days(365.25)     # => true
Horologium::Duration.julian_centuries(0.25)
```

## Intervals

An interval is a span between two instants: an observation campaign, an
eclipse window, a satellite pass. It holds its start and excludes its end, so
one window runs into the next without the two overlapping on the moment they
share, and two windows that merely touch intersect in nothing.

```rb
window = Horologium::Interval.new(
  Horologium::Instant.from_utc(2025, 5, 1),
  Horologium::Instant.from_utc(2025, 5, 1, 2)
)

Horologium::Interval.from(
  Horologium::Instant.from_utc(2025, 5, 1),
  Horologium::Duration.hours(2)
)

window.start
window.end
window.duration
window.cover?(Horologium::Instant.from_utc(2025, 5, 1, 1))
window.overlap?(other)
window.intersection(other)   # => an Interval, or nil
window.to_iso8601(scale: :utc)
```

Its duration is elapsed SI seconds, and that is not the difference the clock
shows. A two-hour window across the 2016 leap second is 7,201 seconds long,
and this is the one place in the library where leap seconds show up without
anyone having asked about them.

```rb
window = Horologium::Interval.parse(
  "2016-12-31T23:00Z/2017-01-01T01:00Z",
  scale: :utc,
  precision: :exact
)

window.duration.in_seconds  # => (7201/1)
```

Repeating intervals (`R5/…`) are not read. Repetition is scheduling, and
scheduling is [ice_cube]'s problem, not this library's.

Durations add, subtract, and negate among themselves, scale by a plain number,
and read back out in SI seconds.

```rb
Horologium::Duration.seconds(30) + Horologium::Duration.seconds(12)
Horologium::Duration.seconds(30) - Horologium::Duration.seconds(42)  # negative
-Horologium::Duration.seconds(3)

Horologium::Duration.hours(1) * 1.5  # => 90 minutes
Horologium::Duration.hours(1) / 2    # => 30 minutes

Horologium::Duration.mean(
  [Horologium::Duration.seconds(1), Horologium::Duration.seconds(3)]
)  # => 2 seconds

Horologium::Duration.days(1).to_r  # => (86400/1), the whole value
Horologium::Duration.days(1).to_f  # => 86400.0
```

Scaling matters more than it looks. A quantity you can only add to another of
its kind sends you back to raw seconds the moment you need half of one, and
the precision the type exists to protect goes with you.

A duration reads and writes ISO 8601, in the subset that is a quantity of time
rather than a walk through a calendar. Years, months and weeks are refused: a
year is 365 days or 366 and a month is anywhere from 28 to 31, so `P1Y` names
a span the calendar resolves and a duration cannot.

```rb
Horologium::Duration.parse("PT4H5M6S").in_seconds  # => 14706.0
Horologium::Duration.parse("P3D").in_seconds       # => 259200.0
Horologium::Duration.seconds(14_706).to_iso8601    # => "PT4H5M6S"

Horologium::Duration.parse("P1Y")  # => raises ParseError
```

The string holds nanoseconds, so a duration on that grid reads back into
itself and one finer than it does not: an exact third of a second writes as
`PT0.333333333S`, and a quarter of a nanosecond writes as `PT0S`. A third of a
second has no finite decimal form at any resolution, so that is the format
rather than the grid. Use `to_r` where the whole value has to survive.

A duration also reads in a unit. The division happens inside the precision the
duration is held in, so a `:standard` duration keeps the digits a collapsed
`Float` would lose, and an `:exact` one reads as a `Rational`.

```rb
Horologium::Duration.days(1).in_hours                  # => 24.0
Horologium::Duration.hours(12).in_days                 # => 0.5
Horologium::Duration.days(36_525).in_julian_centuries  # => 1.0

exact = Horologium::Duration.julian_years(1, precision: :exact)
exact.in_days  # => (1461/4)
```

Adding a duration to an instant makes sense, but adding two instants together
does not, so it raises an error.

```rb
instant + instant  # => raises Horologium::DimensionalError
```

The astronomical epochs are built as instants, so the elapsed time since one is
a subtraction and no Julian Date is involved.

```rb
instant = Horologium::Instant.from_tt(2026, 1, 1)

(instant - Horologium::Epochs::J2000).to_f  # => 820497600.0 SI seconds
```

The scale is part of an epoch's definition. `J2000` is noon TT, which is 64.184
seconds away from noon UTC on the same day.

```rb
Horologium::Epochs::J2000              # 2000-01-01 12:00:00 TT
Horologium::Epochs::J1900              # 1899-12-31 12:00:00 TT
Horologium::Epochs::GPS_ZERO           # 1980-01-06 00:00:00 UTC
Horologium::Epochs::UNIX               # 1970-01-01 00:00:00 UTC
Horologium::Epochs::TT_TCG_TCB_ORIGIN  # 1977-01-01 00:00:00 TAI
```

An epoch is fixed at `:exact`, since it is a definition. Subtracting one from a
`:standard` instant gives an `:exact` duration, the way any other mix of the two
does.

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

- `:standard`, the default, keeps the value as a two-part float. It stays
  within a few nanoseconds of the true value.
- `:exact` keeps the value as a `Rational`, with no rounding. The test suite
  uses it to check that `:standard` stays within its stated precision.

Set the default once at boot. `Horologium.configure` freezes the configuration
when its block returns, so it is called once and everything is set in the one
block. A second call raises `Horologium::ConfigurationError`.

```rb
Horologium.configure do |c|
  c.default_precision = :exact
  c.leap_second_horizon = :raise
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

A library can depend on Horologium without taking the configuration away from
the application that depends on it. Reading the configuration does not freeze
it, so a gem that converts an instant while it loads still leaves
`Horologium.configure` open to the host. And a value built with an explicit
`precision:` ignores the default, so a gem that pins its own precision computes
the same thing whatever the host sets.

Exactness is contagious. An operation between two `:standard` values stays
`:standard`. Mixing a `:standard` and an `:exact` value gives an `:exact`
result, so precision is not quietly lost. `:exact` guarantees the arithmetic
Horologium performs. It cannot bring back precision that an input already lost
when it was built.

A `:standard` value turns a `Rational` into a pair of `Float`s on the way in and
back again on the way out, and that conversion costs more than the arithmetic it
feeds. So `:exact` is the faster one whenever a `Rational` goes in or comes out,
by up to about twice on a build and a read. With a `Float` in and a `Float` out
the two are close enough that the machine decides. `:standard` is the cheaper
one for a long run of arithmetic between values already held that way. Mixing
the two is the expensive case, because promoting a `:standard` value to a
`Rational` costs more than the operation it is promoted for, so inside a loop it
is worth keeping to one precision. `bin/benchmark` measures all of this on your
own machine.

## Status

This library is in early development, before its first public release. The
public API is not stable, so new versions will probably introduce breaking
changes until a 1.0 release. Changes are documented in the [CHANGELOG].

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake` to run the tests and RuboCop, or `rake steep` to type-check the
signatures in `sig/`. Run `COVERAGE=true rake test` to measure test coverage,
which is enforced at 100% of lines and branches in CI. You can also run
`bin/console` for an interactive prompt that will allow you to experiment.

`sig/` holds Horologium's own signatures and ships with the gem. `sig-vendor/`
holds stubs for gems that ship none of their own, and stays out of the gem so
it cannot clash with a downstream RBS collection.

Run `bin/benchmark` to time the paths a consumer runs in a loop and count the
objects each one allocates. Timings drift by a few percent between runs, so it
rotates the order of the cases and reports the fastest round for each. The
allocation counts do not drift, so where a timing and a count disagree, trust
the count. Run it on a branch and on `main` to compare.

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
[ice_cube]: https://github.com/ice-cube-ruby/ice_cube
[iers]: https://github.com/rhannequin/iers
[CHANGELOG]: https://github.com/rhannequin/horologium/blob/main/CHANGELOG.md
[rubygems.org]: https://rubygems.org
[MIT License]: https://opensource.org/licenses/MIT
[code of conduct]: https://github.com/rhannequin/horologium/blob/main/CODE_OF_CONDUCT.md
