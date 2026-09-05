# frozen_string_literal: true

require "test_helper"

# GPS time is a fixed 19 SI seconds behind TAI, and stays there: it counts SI
# seconds and never takes a leap second. The Julian Date 2444244.5 is
# 1980-01-06 00:00:00 UTC, where GPS time started, and TAI - UTC was 19
# seconds that day, which is where the offset comes from.
class TestScalesGPS < Minitest::Test
  def test_the_offset_is_19_seconds
    assert_equal 19, Horologium::Scales::GPS::SECONDS_BEHIND_TAI
  end

  def test_gps_runs_19_seconds_behind_tai
    value = Horologium::Numeric::Exact.new(2_460_000.5)

    reading = Horologium::Scales::GPS.from_reference(value, :exact)

    assert_equal(-19,
      (reading.to_r - value.to_r) * Horologium::Duration::SECONDS_PER_DAY)
  end

  def test_reading_tai_in_gps_is_exact
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::GPS.from_reference(value, :exact)

    assert_equal Rational(2_443_144.5.to_r - Rational(19, 86_400)),
      reading.to_r
  end

  def test_reading_gps_back_into_tai_returns_the_value_it_came_from
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::GPS.from_reference(value, :exact)

    assert_equal value.to_r,
      Horologium::Scales::GPS.to_reference(reading, :exact).to_r
  end

  def test_a_standard_round_trip_stays_within_a_nanosecond
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::GPS.from_reference(value, :standard)
    round_trip = Horologium::Scales::GPS.to_reference(reading, :standard)

    assert_operator (round_trip.to_r - value.to_r).abs, :<,
      Rational(1, 86_400 * 1_000_000_000)
  end

  def test_gps_time_starts_at_midnight_utc_on_1980_01_06
    instant = Horologium::Instant.from_gps(1980, 1, 6, precision: :exact)

    assert_equal "1980-01-06T00:00:00.000000000Z",
      instant.to(:utc).as(:iso8601)
  end

  def test_gps_zero_is_the_epoch_the_library_ships
    assert_equal Horologium::Epochs::GPS_ZERO,
      Horologium::Instant.from_gps(1980, 1, 6, precision: :exact)
  end

  def test_gps_has_run_ahead_of_utc_since_the_leap_seconds_of_the_1980s
    instant = Horologium::Instant.from_utc(2024, 1, 1, precision: :exact)

    gps = instant.to(:gps).as(:julian_date, as: :rational)
    utc = instant.to(:utc).as(:julian_date, as: :rational)

    assert_equal 18,
      (gps - utc) * Horologium::Duration::SECONDS_PER_DAY
  end

  def test_a_standard_reading_stays_a_two_part_float
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::GPS.from_reference(value, :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, reading
  end

  def test_an_exact_reading_stays_exact
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::GPS.from_reference(value, :exact)

    assert_instance_of Horologium::Numeric::Exact, reading
  end

  def test_it_rejects_an_unrecognised_precision
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Scales::GPS.from_reference(value, :fast)
    end
  end
end
