# frozen_string_literal: true

require "test_helper"

class TestScalesUT1 < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_reads_an_instant_in_ut1
    instant = Horologium::Instant.from_ut1(2000, 1, 1, 12, precision: :exact)

    assert_equal "2000-01-01T12:00:00.000000000",
      instant.as(:iso8601, scale: :ut1)
  end

  def test_reading_ut1_back_into_tai_returns_the_instant_it_came_from
    instant = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )

    round_trip = Horologium::Instant.from_julian_date(
      instant.as(:julian_date, scale: :ut1, as: :rational),
      scale: :ut1,
      precision: :exact
    )

    assert_equal instant, round_trip
  end

  def test_a_standard_round_trip_stays_within_a_nanosecond
    instant = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :standard
    )

    two_part = instant.as(:julian_date, scale: :ut1, as: :two_part)
    round_trip = Horologium::Instant.from_julian_date(
      two_part.high,
      two_part.low,
      scale: :ut1,
      precision: :standard
    )

    assert instant.equal_within?(
      round_trip,
      Horologium::Duration.nanoseconds(1)
    )
  end

  def test_ut1_stays_within_a_second_of_utc
    instant = Horologium::Instant.from_utc(2023, 1, 1, precision: :exact)

    difference = instant.as(:julian_date, scale: :ut1, as: :rational) -
      instant.as(:julian_date, scale: :utc, as: :rational)

    assert_operator (difference * Horologium::Duration::SECONDS_PER_DAY).abs,
      :<, 1
  end

  def test_a_pre_1961_instant_reads_in_ut1_where_it_cannot_read_in_utc
    instant = Horologium::Instant.from_ut1(1955, 1, 1, 12, precision: :exact)

    assert_equal "1955-01-01T12:00:31.047050952",
      instant.as(:iso8601, scale: :tt)
    assert_raises(Horologium::OutOfRangeError) do
      instant.as(:iso8601, scale: :utc)
    end
  end

  def test_it_reads_a_1972_date
    instant = Horologium::Instant.from_ut1(1972, 7, 1, precision: :exact)

    assert_equal :estimated, instant.to(:ut1).provenance
  end

  def test_an_instant_at_the_earliest_covered_date_reads_back
    instant = Horologium::Instant.from_julian_date(
      2_378_495.0000116,
      scale: :tt,
      precision: :exact
    )

    round_trip = Horologium::Instant.from_julian_date(
      instant.as(:julian_date, scale: :ut1, as: :rational),
      scale: :ut1,
      precision: :exact
    )

    assert instant.equal_within?(
      round_trip,
      Horologium::Duration.nanoseconds(1)
    )
  end

  def test_it_refuses_a_date_before_the_polynomial_reaches
    assert_raises(Horologium::OutOfDataRangeError) do
      Horologium::Instant.from_ut1(1790, 1, 1, precision: :exact)
    end
  end

  def test_it_reads_a_date_past_the_published_series_with_the_last_delta_t
    instant = Horologium::Instant.from_ut1(2035, 1, 1, precision: :exact)

    assert_equal :extrapolated, instant.to(:ut1).provenance
  end

  def test_a_date_past_the_published_series_still_reads_back
    instant = Horologium::Instant.from_tt(2035, 1, 1, precision: :exact)

    round_trip = Horologium::Instant.from_julian_date(
      instant.as(:julian_date, scale: :ut1, as: :rational),
      scale: :ut1,
      precision: :exact
    )

    assert_equal instant, round_trip
  end

  def test_strict_mode_refuses_a_date_past_the_published_series
    Horologium.configure { |c| c.ut1_horizon = :raise }

    assert_raises(Horologium::OutOfDataRangeError) do
      Horologium::Instant.from_ut1(2035, 1, 1, precision: :exact)
    end
  end

  def test_strict_mode_still_reads_a_date_the_data_covers
    Horologium.configure { |c| c.ut1_horizon = :raise }

    instant = Horologium::Instant.from_ut1(2020, 1, 1, precision: :exact)

    assert_equal :measured, instant.to(:ut1).provenance
  end

  def test_a_date_before_the_polynomial_is_refused_in_either_mode
    Horologium.configure { |c| c.ut1_horizon = :extrapolate }

    assert_raises(Horologium::OutOfDataRangeError) do
      Horologium::Instant.from_ut1(1790, 1, 1, precision: :exact)
    end
  end

  def test_a_source_stating_no_horizon_has_none
    source = Class.new do
      def delta_t_at(_julian_date) = 70.0

      def provenance_at(_julian_date) = :measured

      def covers_until = nil
    end.new

    Horologium.configure { |c| c.eop_source = source }

    instant = Horologium::Instant.from_ut1(2200, 1, 1, precision: :exact)

    assert_equal :measured, instant.to(:ut1).provenance
  end

  # The horizon is a UTC date, since that is how the series is indexed, and a
  # UT1 coordinate sits up to 0.9 s from the UTC one. An instant the data
  # covers must not be called extrapolated because its UT1 name crossed the
  # line the instant itself did not.
  def test_an_instant_inside_the_horizon_is_not_extrapolated_by_its_ut1_name
    source = Class.new do
      def delta_t_at(_julian_date) = 32.184 + 37 - 0.8

      def provenance_at(_julian_date) = :measured

      def covers_until = 2_461_652.5
    end.new

    Horologium.configure { |c| c.eop_source = source }

    instant = Horologium::Instant.from_julian_date(
      2_461_652.5 - Rational(1, 864_000),
      scale: :utc,
      precision: :exact
    )

    assert_equal :measured, instant.to(:ut1).provenance
  end

  # Two horizons, two policies. Refusing extrapolated leap seconds is about
  # reading UTC, and UT1 only uses the UTC date as a lookup key, so it says
  # nothing about whether UT1 answers.
  def test_a_strict_leap_second_horizon_does_not_refuse_ut1
    Horologium.configure do |c|
      c.leap_second_horizon = :raise
      c.ut1_horizon = :extrapolate
    end

    instant = Horologium::Instant.from_tt(2030, 1, 1, precision: :exact)

    assert_equal :extrapolated, instant.to(:ut1).provenance
  end

  def test_both_horizons_strict_still_refuses
    Horologium.configure do |c|
      c.leap_second_horizon = :raise
      c.ut1_horizon = :raise
    end

    assert_raises(Horologium::OutOfDataRangeError) do
      Horologium::Instant.from_tt(2030, 1, 1, precision: :exact)
        .as(:julian_date, scale: :ut1)
    end
  end

  def test_it_refuses_a_source_whose_horizon_is_not_a_number
    source = Class.new do
      def delta_t_at(_julian_date) = 70.0

      def provenance_at(_julian_date) = :measured

      def covers_until = "soon"
    end.new

    Horologium.configure { |c| c.eop_source = source }

    assert_raises(Horologium::ConfigurationError) do
      Horologium::Instant.from_ut1(2020, 1, 1, precision: :exact)
    end
  end

  def test_a_reading_the_series_observed_is_measured
    instant = Horologium::Instant.from_utc(2020, 1, 1, precision: :exact)

    assert_equal :measured, instant.to(:ut1).provenance
  end

  def test_a_reading_the_polynomial_answered_is_estimated
    instant = Horologium::Instant.from_ut1(1900, 1, 1, precision: :exact)

    assert_equal :estimated, instant.to(:ut1).provenance
  end

  def test_a_standard_reading_stays_a_two_part_float
    value = Horologium::Numeric::TwoPartFloat.new(2_460_000.5)

    reading = Horologium::Scales::UT1.from_reference(value, :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, reading
  end

  def test_an_exact_reading_stays_exact
    value = Horologium::Numeric::Exact.new(2_460_000.5)

    reading = Horologium::Scales::UT1.from_reference(value, :exact)

    assert_instance_of Horologium::Numeric::Exact, reading
  end

  def test_it_rejects_an_unrecognised_precision
    value = Horologium::Numeric::TwoPartFloat.new(2_460_000.5)

    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Scales::UT1.from_reference(value, :fast)
    end
  end

  def test_it_reads_delta_t_from_the_configured_source
    source = Class.new do
      def delta_t_at(_julian_date) = 70.0

      def provenance_at(_julian_date) = :measured
    end.new

    Horologium.configure { |c| c.eop_source = source }

    instant = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )
    difference = instant.as(:julian_date, scale: :tt, as: :rational) -
      instant.as(:julian_date, scale: :ut1, as: :rational)

    assert_equal 70,
      difference * Horologium::Duration::SECONDS_PER_DAY
  end
end
