# Changelog

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
