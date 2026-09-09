# Horologium

[![Tests](https://github.com/rhannequin/horologium/workflows/CI/badge.svg)](https://github.com/rhannequin/horologium/actions?query=workflow%3ACI)

Horologium is a Ruby library for **scientific time**. It provides the time
scales ([TAI], [TT], [TDB], [TCG], [TCB], [GPS], [UTC] and [UT1]),
high-precision instants, [Julian Dates], intervals, and the conversions between
scales that astronomy and physics need.

Ruby already provides `Time`, `Date`, `DateTime` and `ActiveSupport` to work
with civil time: time zones, calendars and human formatting. They do not cover
the difference between UTC and a continuous scale, the TAI, TT and TDB scales an
ephemeris needs, or a Julian Date precise to the nanosecond. This is what
Horologium is made for.

## Content

- [Installation](#installation)
- [Usage](#usage)
  - [Read an instant in another scale](#read-an-instant-in-another-scale)
  - [Calendar dates](#calendar-dates)
  - [Ruby's `Time` and Unix time](#rubys-time-and-unix-time)
  - [Time scales](#time-scales)
  - [ISO 8601 strings](#iso-8601-strings)
  - [Julian Dates](#julian-dates)
  - [Durations](#durations)
  - [Instant arithmetic](#instant-arithmetic)
  - [Epochs](#epochs)
  - [Compare instants](#compare-instants)
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

An `Instant` is a single point in time, stored as a TAI Julian Date. A
`Duration` is an amount of time in SI seconds, without a date and without a
scale. You can add a duration to an instant, and subtract two instants to get
the duration between them.

```rb
require "horologium"

a = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
b = Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)

a + Horologium::Duration.days(1) == b        # => true
a < b                                        # => true
b - a == Horologium::Duration.days(1)        # => true
```

### Read an instant in another scale

An instant does not have a scale. You build it from a Julian Date expressed in
one scale, and you can read it back in any scale the library supports. `to`
selects the scale, and `as` selects the format.

```rb
instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

instant.to(:tt).as(:julian_date)               # => 2443144.5003725
instant.as(:modified_julian_date, scale: :tt)  # => 43144.0003725
```

### Calendar dates

A calendar date is another format. It is returned as a `CivilTime`, which holds
the fields a clock and a calendar display, in the proleptic Gregorian calendar.

```rb
instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)
civil = instant.as(:civil, scale: :tt)

civil.year    # => 1977
civil.month   # => 1
civil.second  # => 32
```

You can also build an instant from these fields, and no precision is lost. The
date becomes a whole number of days, and the time of day a fraction of a day. If
you need a fractional second, provide it as a `Rational` to keep it exact.

```rb
Horologium::Instant.from_civil(2025, 5, 1, 12, 0, 0, scale: :tt)
Horologium::Instant.from_civil(2025, 5, 1, 12, 0, Rational(1, 4), scale: :tt)
```

A date that does not exist raises an error.

```rb
Horologium::Instant.from_civil(1900, 2, 29, scale: :tt)
# => raises Horologium::InvalidCivilTimeError
```

### Ruby's `Time` and Unix time

An instant can also be built from a Ruby `Time`, from the system clock, from
Unix time, or from an epoch and a duration. A `Time` is read in UTC and all of
its fields are used. Nothing is rounded, because `subsec` is already a
`Rational`.

```rb
Horologium::Instant.now
Horologium::Instant.from_time(Time.utc(2025, 5, 1, 12))
Horologium::Instant.from_unix(1_370_351_716.32)

Horologium::Instant.from_offset(
  Horologium::Epochs::J2000,
  Horologium::Duration.julian_centuries(0.25)
)
```

Unix time is a way of writing a UTC date. It ignores leap seconds, so reaching a
UTC date takes one more SI second for every leap second inserted before it.
`from_unix(1_700_000_000)` and `Epochs::UNIX + Duration.seconds(1_700_000_000)`
are about 29 seconds apart, and the first one is later.

A `Time` cannot hold a leap second. `Time.utc(2016, 12, 31, 23, 59, 60)` is
silently the first moment of 2017, because POSIX time ignores leap seconds and
all of its days are 86,400 seconds long. `from_time` is exact for every value a
`Time` can hold. If a timestamp had a second 60, it was already lost before
Horologium received it, so please read it with `from_utc` or `from_iso8601`.

### Time scales

Each scale has its own constructor, so you can provide the scale in the method
name instead of a keyword argument.

```rb
Horologium::Instant.from_tt(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tai(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tdb(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tcg(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_tcb(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_gps(2025, 5, 1, 12, 0, 0)
Horologium::Instant.from_ut1(2025, 5, 1, 12, 0, 0)
```

#### TDB

TDB is computed from a model. Horologium uses the full 787-term Fairhead and
Bretagnon series, the same one [ERFA] uses in `dtdb`.

#### TCG, TCB and GPS

TCG and TCB are the coordinate times of the Earth-centred and barycentric
frames. They both run faster than the scale they are defined on, at a rate fixed
by definition. TCG gains about 22 milliseconds a year on TT, and TCB about half
a second a year on TDB, both counted from 1977-01-01 00:00:00 TAI. TCB is
converted to TAI through TDB, so it also depends on the TDB model. GPS time is
19 SI seconds behind TAI. This offset never changes, because GPS counts SI
seconds and ignores leap seconds.

```rb
instant = Horologium::Instant.from_julian_date(2_451_545.0, scale: :tt)

instant.to(:tcg).as(:julian_date)  # => 2451545.0000058548
instant.to(:tcb).as(:julian_date)  # => 2451545.000130251
instant.to(:gps).as(:julian_date)  # => 2451544.9994075927
```

#### UT1

UT1 follows the rotation of the Earth, which is irregular. It is the only scale
here whose value is measured. Horologium gets the difference from the [iers] gem
and converts with `UT1 = TT - delta T`. This formula also works before 1961, a
period where UTC is not defined and a UTC conversion raises an error. Delta T is
estimated with a polynomial fit as far back as 1800, so a UT1 date is still
available there.

```rb
instant = Horologium::Instant.from_ut1(1955, 1, 1, 12)

instant.as(:iso8601, scale: :tt)   # => "1955-01-01T12:00:31.047050952"
instant.as(:iso8601, scale: :utc)  # => raises OutOfRangeError
```

A UT1 conversion tells you where its value comes from. It is `:measured` when
the published series observed it, `:extrapolated` when the series predicts it,
and `:estimated` when the series does not cover the date and the polynomial was
used.

```rb
Horologium::Instant.from_utc(2020, 1, 1).to(:ut1).provenance  # => :measured
Horologium::Instant.from_ut1(1900, 1, 1).to(:ut1).provenance  # => :estimated
```

After the end of the published data, the last known delta T is used and the
provenance is `:extrapolated`. This value is a projection and its error is not
bounded. Delta T follows the rotation of the Earth, which drifts, and a leap
second that has not been announced yet adds one more second. The data usually
covers a few months ahead, and within these months the error is worth
milliseconds. It grows with time and reaches seconds after a few years. Delta T
has recently been changing by about 0.04 seconds a year, and by about 0.47
seconds a year on average over the last fifty years. If your code must not
compute on an extrapolated value, the conversion can raise an error instead.

```rb
Horologium.configure { |c| c.ut1_horizon = :raise }
```

#### UTC and leap seconds

UTC is the scale of civil clocks. It gets a leap second from time to time to
stay close to the rotation of the Earth. `from_utc` reads a UTC date, and a leap
second is a valid value. On a day that has one, the second is 60.

```rb
Horologium::Instant.from_utc(2025, 5, 1, 12, 0, 0)

leap = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)
leap.as(:iso8601, scale: :utc)  # => "2016-12-31T23:59:60.000000000Z"
```

A leap second is a real second, so the arithmetic around it is correct. The
second before 23:59:60, the leap second itself and the next midnight are each
one SI second apart. A second 60 on a day without a leap second raises an error.

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

The `:exact` precision above is what makes `==` work here. With the default
`:standard` precision, the same three instants are a rounding step apart, less
than a nanosecond but more than zero, so please compare them with
`equal_within?`.

UTC starts in 1961. Whole leap seconds are used from 1972. Before that, a UTC
second was slightly longer than an SI one and the difference was adjusted
regularly. An earlier UTC date raises `Horologium::OutOfRangeError`. The instant
itself is still available, and the error mentions the continuous scales, which
are defined at this date. The leap seconds and the rate adjustments come from
the [iers] gem. There is no network access, the data is shipped with the gem.

```rb
Horologium::Instant.from_utc(1960, 12, 31)                  # => OutOfRangeError
Horologium::Instant.from_civil(1960, 12, 31, scale: :tt)    # => an Instant
```

Leap seconds are announced about six months in advance. After the last date
covered by the data, the last known offset is used. A UTC conversion tells you
which offset it is based on. It is `:measured` until this date, and
`:extrapolated` after it, where a leap second announced in the meantime would
not be known. If your code must not depend on an offset that a leap second could
change, the conversion can raise an error instead.

```rb
Horologium::Instant.from_utc(2020, 1, 1).to(:utc).provenance  # => :measured

Horologium.configure { |c| c.leap_second_horizon = :raise }
# => reading a date past the data horizon raises OutOfDataRangeError
```

The configuration is set once, in a single `Horologium.configure` block, and is
frozen when the block returns. See [Precision](#precision).

### ISO 8601 strings

An instant can be written as an extended ISO 8601 string, and read back from
one. The scale is not part of the string. ISO 8601 has no designator for TAI or
TT, and `Z` means UTC, so a string without a suffix is expressed in the scale
you asked for.

```rb
instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

instant.as(:iso8601, scale: :tt)   # => "1977-01-01T00:00:32.184000000"

Horologium::Instant.from_iso8601("2025-05-01T12:00:00", scale: :tt)
Horologium::Instant.from_iso8601("2025-05-01", scale: :tt)  # midnight
```

The parser supports a strict subset: a calendar date, an optional time of day
after a `T`, a fraction of a second with as many digits as you need, and an
optional `Z` or numeric offset. The offset is applied as a simple arithmetic
operation, no time zone data is used. A week date, an ordinal date, or anything
outside of this subset raises a `ParseError`.

### Julian Dates

A Julian Date is around 2.46 million today. A single `Float` has about 40
microseconds of precision left for the fraction of a day, and this precision is
already lost in the literal before Horologium receives it. A `String` and a
`Rational` express the Julian Date exactly, and a high and a low part express it
with about twice the precision of a single `Float`.

```rb
Horologium::Instant.from_julian_date("2456463.052272", scale: :tt)
Horologium::Instant.from_julian_date(
  Rational(2_456_463_052_272, 1_000_000),
  scale: :tt
)
Horologium::Instant.from_julian_date(2_456_463.0, 0.052272, scale: :tt)

Horologium::Instant.from_modified_julian_date(60_796.0, scale: :tai)
```

### Durations

A `Duration` counts SI seconds, so `Duration.days(1)` is always 86,400 SI
seconds. Because of leap seconds, a civil day can be one second longer or
shorter. A duration and a calendar day are two different things.

```rb
Horologium::Duration.days(1) == Horologium::Duration.seconds(86_400)  # => true
Horologium::Duration.nanoseconds(1_000_000_000) ==
  Horologium::Duration.seconds(1)                                     # => true

Horologium::Duration.minutes(90)
Horologium::Duration.hours(6)
Horologium::Duration.zero
```

#### Julian years and centuries

A Julian year is exactly 365.25 days and a Julian century is 36,525 days. These
are astronomical constants. A calendar year has 365 or 366 days, so a Julian
year ends a few hours away from the same date the next year.

```rb
Horologium::Duration.julian_years(1) ==
  Horologium::Duration.days(365.25)     # => true
Horologium::Duration.julian_centuries(0.25)
```

#### Duration arithmetic

Durations can be added, subtracted and negated together. They can also be
multiplied and divided by a number, and read in SI seconds.

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

#### ISO 8601 durations

A duration can be read from and written to ISO 8601, in the subset that
expresses a quantity of time. Years, months and weeks raise an error. A year has
365 or 366 days and a month has between 28 and 31 days, so `P1Y` is an amount of
time that only a calendar can resolve.

```rb
Horologium::Duration.parse("PT4H5M6S").in_seconds  # => 14706.0
Horologium::Duration.parse("P3D").in_seconds       # => 259200.0
Horologium::Duration.seconds(14_706).to_iso8601    # => "PT4H5M6S"

Horologium::Duration.parse("P1Y")  # => raises ParseError
```

The string is limited to nanoseconds. A duration expressed in nanoseconds is
read back exactly. A more precise one loses its extra digits. An exact third of
a second is written `PT0.333333333S`, and a quarter of a nanosecond is written
`PT0S`. A third of a second has no finite decimal representation, so a higher
resolution would not help. You can use `to_r` when the whole value must be kept.

#### Read a duration in a unit

A duration can also be read in a unit. The division is done with the precision
of the duration, so a `:standard` duration keeps the digits a single `Float`
would lose, and an `:exact` one is read as a `Rational`.

```rb
Horologium::Duration.days(1).in_hours                  # => 24.0
Horologium::Duration.hours(12).in_days                 # => 0.5
Horologium::Duration.days(36_525).in_julian_centuries  # => 1.0

exact = Horologium::Duration.julian_years(1, precision: :exact)
exact.in_days  # => (1461/4)
```

### Instant arithmetic

Adding a duration to an instant makes sense, but adding two instants together
does not, so it raises an error.

```rb
instant = Horologium::Instant.from_tt(2026, 1, 1)

instant + Horologium::Duration.hours(1)  # => an Instant
instant + instant                        # => raises DimensionalError
```

### Epochs

The astronomical epochs are built as instants, so the elapsed time since one is
a subtraction and no Julian Date is involved.

```rb
instant = Horologium::Instant.from_tt(2026, 1, 1)

(instant - Horologium::Epochs::J2000).to_f  # => 820497600.0 SI seconds
```

The scale is part of an epoch's definition. `J2000` is noon TT, which is 64.184
seconds before noon UTC on the same day.

```rb
Horologium::Epochs::J2000              # 2000-01-01 12:00:00 TT
Horologium::Epochs::J1900              # 1899-12-31 12:00:00 TT
Horologium::Epochs::GPS_ZERO           # 1980-01-06 00:00:00 UTC
Horologium::Epochs::UNIX               # 1970-01-01 00:00:00 UTC
Horologium::Epochs::TT_TCG_TCB_ORIGIN  # 1977-01-01 00:00:00 TAI
```

An epoch is always `:exact`, because it is a definition. Subtracting one from a
`:standard` instant gives an `:exact` duration, like any other operation mixing
the two precisions.

### Compare instants

Scientific code rarely needs exact equality, so you can compare two instants
with a tolerance.

```rb
a = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
near = a + Horologium::Duration.nanoseconds(1)

a.equal_within?(near, Horologium::Duration.nanoseconds(2))  # => true
```

## Intervals

An interval is an amount of time between two instants: an observation campaign,
an eclipse window, a satellite pass. It includes its start and excludes its end,
so a window can be followed by another one without sharing a common instant. Two
windows that only touch do not overlap.

```rb
window = Horologium::Interval.new(
  Horologium::Instant.from_utc(2025, 5, 1),
  Horologium::Instant.from_utc(2025, 5, 1, 2)
)

later = Horologium::Interval.from(
  Horologium::Instant.from_utc(2025, 5, 1, 1),
  Horologium::Duration.hours(2)
)

window.start
window.end
window.duration
window.cover?(Horologium::Instant.from_utc(2025, 5, 1, 1))
window.overlap?(later)      # => true
window.intersection(later)  # => an Interval, or nil
window.to_iso8601(scale: :utc)
```

Its duration is the elapsed time in SI seconds, which is not always the
difference displayed by a clock. A two-hour window that contains the 2016 leap
second is 7,201 seconds long.

```rb
window = Horologium::Interval.parse(
  "2016-12-31T23:00Z/2017-01-01T01:00Z",
  scale: :utc,
  precision: :exact
)

window.duration.in_seconds  # => (7201/1)
```

Repeating intervals (`R5/…`) are not supported. For scheduling, see [ice_cube].

## Precision

A modern Julian Date is around 2.46 million. A single `Float` uses most of its
digits for this large number and only has tens of microseconds left for the
fraction of a day. This is not precise enough for scientific time. Horologium
stores an instant in two `Float`s whose sum is the Julian Date, the second one
starting where the first one stops. This is the representation used by [ERFA].
It keeps the precision below a nanosecond for any date, with ordinary
floating-point arithmetic.

Every value has one of two precisions, set when it is built:

- `:standard` is the default. It stores the value as a two-part float and stays
  within a few nanoseconds of the true value.
- `:exact` stores the value as a `Rational`, without any rounding. The error of
  `:standard` is measured against exact arithmetic and stays under a nanosecond.

You can set the default once, when your application boots.
`Horologium.configure` freezes the configuration when its block returns, so
everything must be set in a single block. A second call raises
`Horologium::ConfigurationError`.

```rb
Horologium.configure do |c|
  c.default_precision = :exact
  c.leap_second_horizon = :raise
end
```

You can also choose the precision for a single value, or for a block:

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
the application. Reading the configuration does not freeze it, so a gem that
converts an instant while it loads still lets the application call
`Horologium.configure`. A value built with an explicit `precision:` ignores the
default, so a gem that sets its own precision computes the same result whatever
the application configures.

An operation between two `:standard` values returns a `:standard` value. An
operation between a `:standard` and an `:exact` value returns an `:exact` value,
so precision is never silently lost. `:exact` only applies to the operations
performed by Horologium. It cannot recover the precision an input has already
lost when it was built.

A `:standard` value converts a `Rational` into two `Float`s when it is built,
and back when it is read. This conversion costs more than the arithmetic itself,
so `:exact` is faster whenever a `Rational` is given or expected. Building an
instant from a `Rational` takes about 1.6 times longer with `:standard`, and
reading one about 1.2 times longer. With a `Float` given and a `Float` expected,
both are close enough that the difference depends on the machine. Arithmetic
between values of the same precision is close as well. An exact value has a
denominator that grows when hundreds of different fractions are added, and
`:standard` becomes cheaper in this case. Mixing both precisions is the most
expensive case, because converting a `:standard` value into a `Rational` costs
more than the operation it is converted for. In a loop, it is better to keep a
single precision. `bin/benchmark` measures all of this on your own machine.

## Status

This library is still in early development and has not been publicly released
yet. The public API is not stable, please be aware new versions will probably
lead to breaking changes until a 1.0 release. Changes are documented in the
[CHANGELOG].

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake` to run the tests and RuboCop, or `rake steep` to type-check the
signatures in `sig/`. Run `COVERAGE=true rake test` to measure test coverage,
which is enforced at 100% of lines and branches in CI. You can also run
`bin/console` for an interactive prompt that will allow you to experiment.

`sig/` contains Horologium's own signatures and is shipped with the gem.
`sig-vendor/` contains stubs for gems that do not provide any, and is not
shipped with the gem to avoid a conflict with an RBS collection in your
application.

Run `bin/benchmark` to measure the time and the allocated objects of the code
paths that are usually run in a loop. Timings change by a few percent between
runs, so the benchmark rotates the order of the cases and reports the fastest
round for each of them. The allocation counts do not change, so when a timing
and a count disagree, the count is more reliable. You can run it on your branch
and on `main` to compare.

Run `bin/ci` to run every check GitHub Actions runs (RuboCop, Steep, YARD
documentation coverage, and the tests with coverage) in a single command. Every
check is run even when a previous one fails, so you can see everything that
needs to be fixed at once.

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

[TAI]: https://en.wikipedia.org/wiki/International_Atomic_Time
[TT]: https://en.wikipedia.org/wiki/Terrestrial_Time
[TDB]: https://en.wikipedia.org/wiki/Barycentric_Dynamical_Time
[TCG]: https://en.wikipedia.org/wiki/Geocentric_Coordinate_Time
[TCB]: https://en.wikipedia.org/wiki/Barycentric_Coordinate_Time
[GPS]: https://en.wikipedia.org/wiki/Global_Positioning_System
[UTC]: https://en.wikipedia.org/wiki/Coordinated_Universal_Time
[UT1]: https://en.wikipedia.org/wiki/Universal_Time
[Julian Dates]: https://en.wikipedia.org/wiki/Julian_day
[Bundler]: https://bundler.io
[ERFA]: https://github.com/liberfa/erfa
[ice_cube]: https://github.com/ice-cube-ruby/ice_cube
[iers]: https://github.com/rhannequin/iers
[CHANGELOG]: https://github.com/rhannequin/horologium/blob/main/CHANGELOG.md
[rubygems.org]: https://rubygems.org
[MIT License]: https://opensource.org/licenses/MIT
[code of conduct]: https://github.com/rhannequin/horologium/blob/main/CODE_OF_CONDUCT.md
