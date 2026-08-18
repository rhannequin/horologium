# frozen_string_literal: true

require "test_helper"

class TestScalesUtc < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  # The 2016 leap second, the case most libraries get wrong.

  def test_second_60_is_a_valid_reading_on_a_leap_day
    instant = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)

    assert_equal 60, instant.as(:civil, scale: :utc).second
  end

  def test_second_60_writes_in_iso_8601
    instant = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 60)

    assert_equal "2016-12-31T23:59:60.000000000Z",
      instant.as(:iso8601, scale: :utc)
  end

  def test_a_fraction_of_the_leap_second_is_kept
    instant = Horologium::Instant.from_utc(
      2016, 12, 31, 23, 59, Rational(121, 2),
      precision: :exact
    )

    assert_equal "2016-12-31T23:59:60.500000000Z",
      instant.as(:iso8601, scale: :utc)
  end

  def test_second_60_is_refused_on_a_day_with_no_leap_second
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_utc(2020, 6, 15, 23, 59, 60)
    end

    assert_includes error.message, "leap second"
  end

  def test_the_leap_second_is_a_real_second_on_the_timeline
    before = Horologium::Instant.from_utc(
      2016, 12, 31, 23, 59, 59,
      precision: :exact
    )
    leap = Horologium::Instant.from_utc(
      2016, 12, 31, 23, 59, 60,
      precision: :exact
    )
    after = Horologium::Instant.from_utc(2017, 1, 1, 0, 0, 0, precision: :exact)

    assert_equal Horologium::Duration.seconds(1), leap - before
    assert_equal Horologium::Duration.seconds(1), after - leap
  end

  def test_a_second_added_across_the_leap_reads_as_second_60
    before = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 59)

    stepped = before + Horologium::Duration.seconds(1)

    assert_equal 60, stepped.as(:civil, scale: :utc).second
  end

  def test_two_seconds_added_across_the_leap_reads_as_the_next_day
    before = Horologium::Instant.from_utc(2016, 12, 31, 23, 59, 59)

    stepped = before + Horologium::Duration.seconds(2)
    civil = stepped.as(:civil, scale: :utc)

    assert_equal [2017, 1, 1, 0, 0, 0],
      [civil.year, civil.month, civil.day, civil.hour, civil.minute,
        civil.second]
  end

  # The quasi-JD day length.

  def test_a_leap_day_is_86_401_seconds_long
    assert_equal 86_401, Horologium::Scales::UTC.seconds_in_day(2_457_754)
  end

  def test_an_ordinary_day_is_86_400_seconds_long
    assert_equal 86_400, Horologium::Scales::UTC.seconds_in_day(2_458_849)
  end

  # UTC to TAI, and back.

  def test_it_round_trips_utc_to_tai_across_a_leap_boundary
    %i[standard exact].each do |precision|
      instant = Horologium::Instant.from_utc(
        2016, 12, 31, 23, 59, Rational(121, 2),
        precision: precision
      )
      civil = instant.as(:civil, scale: :utc, as: :rational)

      assert_equal 60, civil.second
      assert_equal Rational(1, 2), civil.second_fraction if precision == :exact
    end
  end

  def test_an_ordinary_utc_time_reads_back_as_itself
    instant = Horologium::Instant.from_utc(
      2020, 6, 15, 12, 34, 56,
      precision: :exact
    )
    civil = instant.as(:civil, scale: :utc)

    assert_equal [2020, 6, 15, 12, 34, 56],
      [civil.year, civil.month, civil.day, civil.hour, civil.minute,
        civil.second]
  end

  def test_it_reads_a_civil_time_back_into_the_instant_it_came_from
    instant = Horologium::Instant.from_utc(
      2019, 3, 14, 9, 26, Rational(107, 2),
      precision: :exact
    )
    civil = instant.as(:civil, scale: :utc, as: :rational)

    assert_equal instant,
      Horologium::Instant.from_utc(civil, precision: :exact)
  end

  # The domain: 1972 and the door in the wall.

  def test_a_utc_reading_before_1972_is_refused
    error = assert_raises(Horologium::OutOfRangeError) do
      Horologium::Instant.from_utc(1971, 12, 31, 0, 0, 0)
    end

    assert_includes error.message, "continuous scale"
  end

  def test_the_first_utc_day_is_allowed
    instant = Horologium::Instant.from_utc(1972, 1, 1, 0, 0, 0)

    assert_equal "1972-01-01T00:00:00.000000000Z",
      instant.as(:iso8601, scale: :utc)
  end

  def test_a_pre_1972_instant_is_reachable_in_a_continuous_scale
    instant = Horologium::Instant.from_julian_date(2_440_000.5, scale: :tai)

    assert_kind_of String, instant.as(:iso8601, scale: :tt)
  end

  def test_a_pre_1972_instant_has_no_utc_label
    instant = Horologium::Instant.from_julian_date(2_440_000.5, scale: :tai)

    assert_raises(Horologium::OutOfRangeError) do
      instant.to(:utc)
    end
  end

  # A Julian Date reaches to_reference without passing the calendar, where
  # from_utc is stopped by the day length first.
  def test_a_pre_1972_julian_date_read_in_utc_is_refused
    error = assert_raises(Horologium::OutOfRangeError) do
      Horologium::Instant.from_julian_date(2_441_000.0, scale: :utc)
    end

    assert_includes error.message, "continuous scale"
  end

  # The day guessed from TAI is at most a day out either way. Only a source
  # where UTC runs ahead of TAI guesses a day early, so that is what proves
  # the refinement steps forwards as well as back.
  def test_it_steps_forward_when_the_guessed_day_is_early
    source = Class.new do
      def self.tai_utc_at(_day_number)
        -10
      end
    end
    Horologium.configure { |config| config.leap_second_source = source }
    instant = Horologium::Instant.from_julian_date(
      Rational(2_460_000) + Rational(1, 2) - Rational(5, 86_400),
      scale: :tai,
      precision: :exact
    )

    civil = instant.as(:civil, scale: :utc, as: :rational)

    assert_equal [2023, 2, 25, 0, 0, 5],
      [civil.year, civil.month, civil.day, civil.hour, civil.minute,
        civil.second]
  end

  # A numeric offset shifts by SI seconds, even across a leap second.

  def test_an_iso_offset_on_a_leap_day_shifts_by_si_seconds
    shifted = Horologium::Instant.from_iso8601(
      "2016-12-31T23:59:60+01:00",
      scale: :utc,
      precision: :exact
    )

    assert_equal Horologium::Instant.from_utc(
      2016, 12, 31, 23, 59, 60,
      precision: :exact
    ) - Horologium::Duration.seconds(3600),
      shifted
  end

  # Provenance and the data horizon.

  def test_a_reading_within_the_data_horizon_is_measured
    reading = Horologium::Instant.from_utc(2020, 6, 15, 12).to(:utc)

    assert_equal :measured, reading.provenance
  end

  def test_a_reading_past_the_data_horizon_is_extrapolated
    reading = Horologium::Instant.from_utc(2035, 1, 1, 0).to(:utc)

    assert_equal :extrapolated, reading.provenance
  end

  def test_a_continuous_scale_reading_is_measured
    reading = Horologium::Instant
      .from_julian_date(2_460_000.5, scale: :tai)
      .to(:tt)

    assert_equal :measured, reading.provenance
  end

  def test_strict_mode_refuses_a_projection_past_the_horizon
    Horologium.configure { |config| config.leap_second_horizon = :raise }

    assert_raises(Horologium::OutOfDataRangeError) do
      Horologium::Instant.from_utc(2035, 1, 1, 0).to(:utc)
    end
  end

  def test_strict_mode_refuses_a_construction_past_the_horizon
    Horologium.configure { |config| config.leap_second_horizon = :raise }

    assert_raises(Horologium::OutOfDataRangeError) do
      Horologium::Instant.from_utc(2035, 1, 1, 0)
    end
  end

  def test_strict_mode_still_allows_a_date_within_the_horizon
    Horologium.configure { |config| config.leap_second_horizon = :raise }

    reading = Horologium::Instant.from_utc(2020, 6, 15, 12).to(:utc)

    assert_equal :measured, reading.provenance
  end

  def test_a_source_with_no_expiry_reads_as_measured_throughout
    source = Class.new do
      def self.tai_utc_at(_day_number)
        37
      end
    end
    Horologium.configure { |config| config.leap_second_source = source }

    reading = Horologium::Instant.from_utc(2035, 1, 1, 0).to(:utc)

    assert_equal :measured, reading.provenance
  end

  def test_a_source_that_states_no_expiry_reads_as_measured_throughout
    source = Class.new do
      def self.tai_utc_at(_day_number)
        37
      end

      def self.expires_on
        nil
      end
    end
    Horologium.configure { |config| config.leap_second_source = source }

    reading = Horologium::Instant.from_utc(2035, 1, 1, 0).to(:utc)

    assert_equal :measured, reading.provenance
  end

  def test_a_source_whose_expiry_is_not_a_date_is_refused
    source = Class.new do
      def self.tai_utc_at(_day_number)
        37
      end

      def self.expires_on
        "2026-12-28"
      end
    end
    Horologium.configure { |config| config.leap_second_source = source }

    error = assert_raises(Horologium::ConfigurationError) do
      Horologium::Instant.from_utc(2035, 1, 1, 0).to(:utc)
    end

    assert_includes error.message, "expires_on"
  end

  # Naming and shape.

  def test_from_utc_is_from_civil_read_in_utc
    assert_equal Horologium::Instant.from_civil(
      2020, 6, 15, 12, 0, 0,
      scale: :utc
    ),
      Horologium::Instant.from_utc(2020, 6, 15, 12, 0, 0)
  end

  def test_it_takes_the_precision_in_effect_by_default
    instant = Horologium.with_precision(:exact) do
      Horologium::Instant.from_utc(2020, 6, 15)
    end

    assert_equal :exact, instant.precision
  end

  def test_the_leap_second_source_can_be_replaced
    frozen = Class.new do
      def self.tai_utc_at(_day_number)
        37
      end
    end

    Horologium.configure do |config|
      config.leap_second_source = frozen
    end

    # With a flat 37-second offset and no step, every day is 86,400 seconds.
    assert_equal 86_400, Horologium::Scales::UTC.seconds_in_day(2_458_849)
  end
end
