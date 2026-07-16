# frozen_string_literal: true

require "test_helper"

# The Julian Date 2443144.5 is 1977-01-01 00:00:00 TAI, the origin epoch the
# scales are defined against. Read in TT it is 2443144.5003725, exactly 32.184
# seconds, or 0.0003725 days, later.
class TestScalesTT < Minitest::Test
  def test_the_offset_is_32_point_184_seconds
    assert_equal Rational(32_184, 1_000),
      Horologium::Scales::TT::SECONDS_AHEAD_OF_TAI
  end

  def test_reading_the_origin_epoch_in_tt_is_exact
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::TT.from_reference(value, :exact)

    assert_equal Rational(24_431_445_003_725, 10_000_000), reading.to_r
  end

  def test_reading_the_origin_epoch_in_tt_stays_within_a_nanosecond
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::TT.from_reference(value, :standard)
    error = reading.to_r - Rational(24_431_445_003_725, 10_000_000)

    assert_operator error.abs, :<,
      Rational(1, 86_400 * 1_000_000_000)
  end

  def test_tt_runs_32_point_184_seconds_ahead_of_tai
    value = Horologium::Numeric::Exact.new(2_460_000.5)

    reading = Horologium::Scales::TT.from_reference(value, :exact)

    assert_equal Rational(32_184, 1_000),
      (reading.to_r - value.to_r) * Horologium::Duration::SECONDS_PER_DAY
  end

  def test_reading_tt_back_into_tai_returns_the_value_it_came_from
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::TT.from_reference(value, :exact)

    assert_equal value.to_r,
      Horologium::Scales::TT.to_reference(reading, :exact).to_r
  end

  def test_a_standard_round_trip_stays_within_a_nanosecond
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::TT.from_reference(value, :standard)
    round_trip = Horologium::Scales::TT.to_reference(reading, :standard)

    assert_operator (round_trip.to_r - value.to_r).abs, :<,
      Rational(1, 86_400 * 1_000_000_000)
  end

  def test_a_standard_reading_stays_a_two_part_float
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::TT.from_reference(value, :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, reading
  end

  def test_an_exact_reading_stays_exact
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::TT.from_reference(value, :exact)

    assert_instance_of Horologium::Numeric::Exact, reading
  end

  def test_it_rejects_an_unrecognised_precision
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Scales::TT.from_reference(value, :fast)
    end
  end
end
