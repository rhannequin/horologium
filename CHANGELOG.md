# Changelog

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
