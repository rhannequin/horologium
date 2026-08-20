# frozen_string_literal: true

require "test_helper"

class TestRepresentationsCivil < Minitest::Test
  ROUND_TRIP_DATES = [
    [-4799, 1, 1],
    [-4712, 1, 1],
    [-1, 12, 31],
    [0, 1, 1],
    [0, 2, 29],
    [1, 1, 1],
    [1582, 10, 4],
    [1582, 10, 15],
    [1600, 2, 29],
    [1858, 11, 17],
    [1900, 2, 28],
    [1970, 1, 1],
    [2000, 2, 29],
    [2025, 5, 1],
    [2100, 2, 28],
    [2400, 2, 29],
    [9999, 12, 31]
  ].freeze

  def teardown
    Horologium.reset_configuration!
  end

  def test_it_renders_the_calendar_date_of_the_julian_date_epoch_j2000
    civil = Horologium::Instant
      .from_julian_date(2_451_545.0, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 2000, civil.year
    assert_equal 1, civil.month
    assert_equal 1, civil.day
    assert_equal 12, civil.hour
  end

  def test_it_renders_the_calendar_date_of_the_modified_julian_date_origin
    civil = Horologium::Instant
      .from_julian_date(2_400_000.5, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 1858, civil.year
    assert_equal 11, civil.month
    assert_equal 17, civil.day
    assert_equal 0, civil.hour
  end

  def test_it_renders_the_calendar_date_of_the_unix_epoch
    civil = Horologium::Instant
      .from_julian_date(2_440_587.5, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 1970, civil.year
    assert_equal 1, civil.month
    assert_equal 1, civil.day
  end

  def test_it_renders_the_time_of_day
    civil = Horologium::Instant
      .from_civil(2025, 5, 1, 12, 34, 56, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 12, civil.hour
    assert_equal 34, civil.minute
    assert_equal 56, civil.second
  end

  def test_it_renders_the_date_in_the_scale_the_instant_is_read_in
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_equal 0, instant.as(:civil, scale: :tai).second
    assert_equal 32, instant.as(:civil, scale: :tt).second
  end

  def test_it_renders_the_fraction_of_a_second_as_a_float_by_default
    civil = Horologium::Instant
      .from_civil(2025, 5, 1, 0, 0, Rational(1, 4), scale: :tai)
      .as(:civil, scale: :tai)

    assert_instance_of Float, civil.second_fraction
    assert_in_delta 0.25, civil.second_fraction
  end

  def test_it_renders_the_fraction_of_a_second_as_a_rational_when_asked
    civil = Horologium::Instant
      .from_civil(2025, 5, 1, 0, 0, Rational(1, 4), scale: :tai)
      .as(:civil, scale: :tai, as: :rational)

    assert_instance_of Rational, civil.second_fraction
    assert_in_delta 0.25, civil.second_fraction, 1e-15
  end

  def test_an_exact_reading_keeps_a_fraction_a_float_cannot_hold
    fraction = Rational(1, 3)
    civil = Horologium::Instant
      .from_civil(2025, 5, 1, 0, 0, fraction, scale: :tai, precision: :exact)
      .as(:civil, scale: :tai, as: :rational)

    assert_equal fraction, civil.second_fraction
  end

  def test_a_standard_reading_renders_what_its_two_floats_hold_not_what_it_was_given
    fraction = Horologium::Instant
      .from_civil(2025, 5, 1, 0, 0, Rational(1, 4), scale: :tai)
      .as(:civil, scale: :tai, as: :rational)
      .second_fraction

    refute_equal Rational(1, 4), fraction
    assert_in_delta 0.25, fraction, 1e-15
  end

  def test_it_rejects_an_unknown_output_type
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tai)

    error = assert_raises(Horologium::UnknownOutputError) do
      Horologium::Representations::Civil.render(reading, :two_part)
    end

    assert_equal %i[float rational], error.known_outputs
  end

  def test_it_reads_a_civil_time_back_as_the_julian_date_it_came_from
    ROUND_TRIP_DATES.each do |year, month, day|
      instant = Horologium::Instant.from_civil(
        year, month, day, 13, 47, Rational(23, 2),
        scale: :tai,
        precision: :exact
      )
      civil = instant.as(:civil, scale: :tai, as: :rational)

      assert_equal Horologium::Instant.from_civil(
        civil,
        scale: :tai,
        precision: :exact
      ),
        instant,
        "#{year}-#{month}-#{day} did not read back as itself"
    end
  end

  def test_it_reads_a_civil_time_back_as_the_fields_it_was_given
    ROUND_TRIP_DATES.each do |year, month, day|
      civil = Horologium::Instant
        .from_civil(
          year, month, day, 13, 47, Rational(23, 2),
          scale: :tai,
          precision: :exact
        )
        .as(:civil, scale: :tai, as: :rational)

      assert_equal(
        Horologium::Representations::CivilTime.new(
          year, month, day, 13, 47, 11, Rational(1, 2)
        ),
        civil,
        "#{year}-#{month}-#{day} did not read back as itself"
      )
    end
  end

  def test_the_last_second_of_a_day_stays_inside_it
    civil = Horologium::Instant
      .from_civil(2025, 5, 1, 23, 59, 59, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 1, civil.day
    assert_equal 23, civil.hour
    assert_equal 59, civil.second
  end

  def test_the_first_second_of_a_day_starts_it
    civil = Horologium::Instant
      .from_civil(2025, 5, 2, 0, 0, 0, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 2, civil.day
    assert_equal 0, civil.hour
  end

  def test_a_fraction_that_rounds_up_to_a_whole_day_rolls_into_the_next
    # 2000-01-01 23:59:59.999..., a hair under midnight: the fraction of a
    # second rounds up to a whole one when rendered as a Float, which fills the
    # day and rolls the clock into the next, rather than reading a second that
    # is not there.
    almost = 59 + Rational(10**18 - 1, 10**18)
    civil = Horologium::Instant
      .from_civil(2000, 1, 1, 23, 59, almost, scale: :tai, precision: :exact)
      .as(:civil, scale: :tai)

    assert_equal [2000, 1, 2, 0, 0, 0],
      [civil.year, civil.month, civil.day, civil.hour, civil.minute,
        civil.second]
  end

  def test_the_calendar_is_the_gregorian_one_before_it_was_introduced
    instant = Horologium::Instant.from_civil(1582, 10, 5, scale: :tai)

    assert_equal 5, instant.as(:civil, scale: :tai).day
  end

  def test_a_century_that_is_not_a_leap_year_has_no_february_29
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(1900, 2, 29, scale: :tai)
    end

    assert_includes error.message, "1900-2 has 28 days"
  end

  def test_a_century_divisible_by_four_hundred_has_a_february_29
    civil = Horologium::Instant
      .from_civil(2000, 2, 29, scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 2, civil.month
    assert_equal 29, civil.day
  end

  def test_a_year_before_the_calendar_conversion_starts_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(-4800, 1, 1, scale: :tai)
    end

    assert_includes error.message, "before -4799"
  end

  def test_a_month_outside_the_year_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2025, 13, 1, scale: :tai)
    end

    assert_includes error.message, "13 is not a month"
  end

  def test_a_day_outside_the_month_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2025, 4, 31, scale: :tai)
    end

    assert_includes error.message, "2025-4 has 30 days"
  end

  def test_an_hour_outside_the_day_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2025, 5, 1, 24, scale: :tai)
    end

    assert_includes error.message, "24 is not an hour"
  end

  def test_a_minute_outside_the_hour_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2025, 5, 1, 12, 60, scale: :tai)
    end

    assert_includes error.message, "60 is not a minute"
  end

  def test_second_sixty_is_refused_where_no_scale_has_a_leap_second
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2016, 12, 31, 23, 59, 60, scale: :tai)
    end

    assert_includes error.message, "second 60 is a leap second"
  end

  def test_a_second_outside_the_minute_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2025, 5, 1, 12, 0, 61, scale: :tai)
    end

    assert_includes error.message, "61 is not a second"
  end

  def test_a_negative_second_is_refused
    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_civil(2025, 5, 1, 12, 0, -1, scale: :tai)
    end

    assert_includes error.message, "-1 is not a second"
  end

  def test_a_fraction_of_a_second_of_one_or_more_is_refused
    civil = Horologium::Representations::CivilTime.new(2025, 5, 1, 0, 0, 0, 1.5)

    error = assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Representations::Civil.parse(
        civil,
        nil,
        Horologium::Scales::TAI,
        :standard
      )
    end

    assert_includes error.message, "is not a fraction of a second"
  end

  def test_a_value_that_is_not_a_civil_time_is_refused
    error = assert_raises(ArgumentError) do
      Horologium::Representations::Civil.parse(
        2_443_144.5,
        nil,
        Horologium::Scales::TAI,
        :standard
      )
    end

    assert_includes error.message, "a civil time is a"
  end

  def test_a_whole_field_that_is_not_an_integer_is_refused
    civil = Horologium::Representations::CivilTime.new(2025.0, 5, 1)

    error = assert_raises(ArgumentError) do
      Horologium::Representations::Civil.parse(
        civil,
        nil,
        Horologium::Scales::TAI,
        :standard
      )
    end

    assert_includes error.message, "the year of a civil time is an Integer"
  end

  def test_a_second_the_library_does_not_read_is_refused
    error = assert_raises(ArgumentError) do
      Horologium::Instant.from_civil(2025, 5, 1, 12, 0, "30", scale: :tai)
    end

    assert_includes error.message, "pass a Rational"
  end

  # The way out stops where the way in does.

  def test_the_earliest_date_it_reads_is_the_earliest_it_writes
    earliest = Horologium::Instant.from_civil(
      Horologium::Representations::Civil::MINIMUM_YEAR, 1, 1,
      scale: :tai,
      precision: :exact
    )
    civil = earliest.as(:civil, scale: :tai, as: :rational)

    assert_equal [Horologium::Representations::Civil::MINIMUM_YEAR, 1, 1],
      [civil.year, civil.month, civil.day]
  end

  def test_a_date_before_the_earliest_one_is_refused_on_the_way_out
    instant = Horologium::Instant.from_julian_date(
      -31_739.5,
      scale: :tai,
      precision: :exact
    )

    error = assert_raises(Horologium::InvalidCivilTimeError) do
      instant.as(:civil, scale: :tai)
    end

    assert_includes error.message, "the calendar conversion stops"
  end

  def test_a_reading_out_reads_back_into_the_instant_it_came_from
    instant = Horologium::Instant.from_julian_date(
      -31_738.5,
      scale: :tai,
      precision: :exact
    )

    assert_equal instant,
      Horologium::Instant.from_civil(
        instant.as(:civil, scale: :tai, as: :rational),
        scale: :tai,
        precision: :exact
      )
  end
end
