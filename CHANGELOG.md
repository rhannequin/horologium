# Changelog

## 0.0.5 - 2026-09-08

All eight scales are in, so an instant reads in any of them, and the domain
model is complete: the point, the quantity, and the span between two points.
A `Time` bridges in from the standard library, a duration scales and reads
ISO 8601, and everything the library cannot compute with is refused by name
rather than by whatever Ruby happened to raise.

### Breaking changes

- A value the library cannot read raises `InvalidValueError` instead of
  `ArgumentError`. `Error`'s promise is that a caller can rescue Horologium as
  a unit, and it did not hold: a Float that was not finite came back as
  `FloatDomainError` and a Symbol given to a `Duration` constructor as
  `NoMethodError`. Dividing by zero is the one error left as Ruby's own
- The civil calendar is bounded above as well as below, from -4799 to 2733193,
  the range ERFA documents for its calendar routines. Julian Date 5e9 used to
  read back as the year 13684822 rather than being refused

### Features

- Add `TCG` and `TCB`, the coordinate times of the Earth-centred and
  barycentric frames, each running ahead of the scale it is defined on at a
  rate fixed by definition and counted from 1977-01-01 00:00:00 TAI. TCG
  inverts exactly at `:exact`; TCB's own edge does too, but the way to TAI
  goes through TDB's floating-point model
- Add `GPS`, a fixed 19 SI seconds behind TAI, which is where it stays because
  it counts SI seconds and never takes a leap second
- Add `UT1`, the scale the rotation of the Earth keeps and the only one here
  that is measured rather than defined. It converts as TT minus delta T, which
  is what lets it reach back to 1800: UTC is undefined before 1961 and refuses
  the date, so a pre-1961 instant has a UT1 name where it can never have a UTC
  one. A reading says whether the value was observed, predicted, or fitted
- Add `Configuration#eop_source`, the Earth orientation data UT1 reads, and
  `#ut1_horizon`, which chooses between reading past the end of the published
  data with the last known delta T and refusing to
- Add `Instant.now`, `.from_time`, `.from_unix` and `.from_offset`. A `Time`
  is read in UTC and every field it carries is used, so nothing is rounded on
  the way in. Unix time is read the way POSIX reads it, which is not a count
  of elapsed seconds: it has no leap seconds, so reaching a UTC date costs an
  extra SI second for each one inserted along the way
- Add `Duration#*` and `#/`, which scale a duration by a plain number, and
  `Duration.mean`, which averages a list of them in the split
- Add `Duration.parse` and `Duration#to_iso8601`, reading and writing the
  subset of ISO 8601 that is a quantity of time. Years and months are refused
  because a duration cannot say how long they are; weeks are seven days
  exactly but sit outside the subset all the same
- Add `Interval`, a span between two instants, with `duration`, `cover?`,
  `overlap?`, `intersection` and ISO 8601 either way. It holds its start and
  excludes its end, so one window runs into the next without the two
  overlapping on the moment they share. Its length is elapsed SI seconds, so a
  two-hour window across the 2016 leap second is 7,201 seconds long
- Add `InvalidValueError` and `InvalidIntervalError`

### Fixes

- Refuse a number that does not fit a Float where it has to become one, rather
  than carrying on with an Infinity or a zero. Building a `:standard` value
  from an Integer too large for a Float used to fail later, when the Infinity
  had no rational form, and scaling a duration by a number too small used to
  answer with no duration at all
- Read every part of a two-part Julian Date. A NaN in either part used to
  build an instant and surface later, in a reading, in a civil time, or in a
  comparison
- Read UT1 back into TAI within delta T of the earliest date the data covers.
  Converting out subtracts delta T, so an instant that close to the edge
  landed on a UT1 coordinate just before it, and reading that back refused
- Report no overlap between a span of no time and anything, including a span
  that surrounds it. It covers no instant, so there is no instant for the two
  of them to share
- Stop writing warnings to stderr. `Integer#to_f` warns on its way out of
  range, so the guard that refuses such a number announced it first

**Full Changelog**: https://github.com/rhannequin/horologium/compare/v0.0.4...v0.0.5

## 0.0.4 - 2026-09-05

The epochs astronomy counts from arrive as instants, a duration reads back in
the unit you want it in, and the conversions cost a good deal less than they
did.

### Features

- Add `Epochs`, with `J2000`, `J1900`, `GPS_ZERO`, `UNIX` and
  `TT_TCG_TCB_ORIGIN`. An epoch is an ordinary `Instant`, so the time elapsed
  since one is a subtraction and no Julian Date is involved
- Add the `Duration` constructors `minutes`, `hours`, `julian_years`,
  `julian_centuries` and `zero`, where a Julian year is exactly 365.25 days and
  a Julian century 36,525
- Add `Duration#in_seconds`, `#in_minutes`, `#in_hours`, `#in_days`,
  `#in_julian_years` and `#in_julian_centuries`, which come out as a Float at
  `:standard` and a Rational at `:exact`
- Add `zero?`, `negative?` and `positive?` to `Numeric::TwoPartFloat` and
  `Numeric::Exact`, and `Numeric::Precision.compare`, which orders two values
  by the number they denote whatever precision each is held in

### Improvements

- Build an instant in about half the time at `:standard` and a third less at
  `:exact`, allocating 3 objects where it allocated 30. An instant no longer
  works out its exact Rational value when it is built, the two-part arithmetic
  keeps its intermediate parts in Floats, and a Julian Date given as a single
  Float skips a step it does not need
- Read UTC twice as fast at `:standard` and a third faster at `:exact`. The
  conversion reads each leap second offset once, and settles the day without
  spelling the value out as a Rational
- Read `ScaleReading#provenance` from the scale that took the reading, when it
  is asked rather than on every reading

**Full Changelog**: https://github.com/rhannequin/horologium/compare/v0.0.3...v0.0.4

## 0.0.3 - 2026-08-22

The scale conversions arrive. An instant is now a point with no scale of its
own, given in one scale and read back in another, and it comes out as a Julian
Date, a calendar date, or an ISO 8601 string.

### Features

- Add time scales, each converting to and from TAI, the scale an instant is
  stored in: `TAI`, `TT` at its fixed 32.184 s, `TDB` over the full 787-term
  Fairhead and Bretagnon model, and `UTC` with its leap seconds
- Add `Instant#to`, which reads an instant in a scale, and `ScaleReading`,
  which is that reading, with `#as` for the shape it comes out in
- Add the representations a reading comes out as: `julian_date`,
  `modified_julian_date`, `civil`, and `iso8601`, each as a Float, a Rational,
  or a two-part Float where that makes sense
- Add `Instant.from_julian_date`, `from_modified_julian_date`, `from_civil`,
  and `from_iso8601`, each reading its value in a named scale
- Add `Instant.from_tai`, `from_tt`, `from_tdb`, and `from_utc`, the same
  calendar constructor with the scale in the name
- Add `CivilTime`, the calendar fields a clock and a calendar show, in the
  proleptic Gregorian calendar with astronomical year numbering
- Read and write a leap second as second 60, on the days that hold one, and
  refuse it on the days that do not
- Add `ScaleReading#provenance`, `:measured` up to the date the leap second
  data vouches for and `:extrapolated` after it, with
  `Configuration#leap_second_horizon` to refuse an extrapolation instead
- Add `Configuration#register_scale`, so a caller can add a scale of its own,
  and `Configuration#leap_second_source`, so it can supply its own leap seconds
- Add duration arithmetic: `+`, `-`, unary `-`, `zero?`, `negative?`,
  `positive?`, and `to_r` and `to_f` in SI seconds
- Add value equality to `ScaleReading`, and `inspect` to `Instant`, `Duration`,
  and `ScaleReading`
- Refuse a calendar reading before -4799, where the conversion stops, so a
  reading out always reads back in

### Fixes

- Build the configuration under a lock, so two threads reaching it at once
  cannot each build one and lose the other's scales

**Full Changelog**: https://github.com/rhannequin/horologium/compare/v0.0.2...v0.0.3

## 0.0.2 - 2026-07-14

The first functional release. It ships the numeric core and the two value
objects the rest of the library is built on: `Instant` and `Duration`. The
scale conversions are not here yet, so an instant is built directly from a
TAI Julian Date for now.

### Features

- Add `Numeric::TwoPartFloat`, a number kept as a high and a low `Float` for
  about twice the precision of one, with Shewchuk error-free arithmetic
- Add `Numeric::Exact`, a value kept as an exact `Rational`, with no rounding
- Add the precision contract: every value carries a precision, `:standard` or
  `:exact`, set when it is built and never changed. Mixing the two promotes
  the result to `:exact` instead of dropping to `:standard`
- Add `Horologium.configure` for the set-once default precision, and
  `Horologium.with_precision` for a scoped, per-fiber override
- Add `Instant`, a frozen point on the TAI timeline, built with
  `Instant.from_tai_julian_date`
- Add `Duration`, a frozen span in SI seconds, built with `Duration.seconds`,
  `Duration.days`, and `Duration.nanoseconds`
- Add instant and duration arithmetic: shift an instant by a duration, and
  subtract two instants to measure the duration between them
- Add `Instant#equal_within?` for comparison inside a tolerance
- Guard against meaningless operations: adding two instants raises
  `DimensionalError`

**Full Changelog**: https://github.com/rhannequin/horologium/compare/v0.0.1...v0.0.2

## 0.0.1 - 2026-07-06

- Gem creation
