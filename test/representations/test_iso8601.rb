# frozen_string_literal: true

require "test_helper"

class TestRepresentationsIso8601 < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_writes_the_date_and_time
    string = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .as(:iso8601, scale: :tai)

    assert_equal "1977-01-01T00:00:00.000000000", string
  end

  def test_it_writes_the_time_in_the_scale_it_is_read_in
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_equal "1977-01-01T00:00:00.000000000",
      instant.as(:iso8601, scale: :tai)
    assert_equal "1977-01-01T00:00:32.184000000",
      instant.as(:iso8601, scale: :tt)
  end

  def test_it_writes_no_zone_designator_for_a_continuous_scale
    string = Horologium::Instant
      .from_civil(2025, 5, 1, 12, scale: :tai)
      .as(:iso8601, scale: :tai)

    refute_includes string, "Z"
  end

  def test_it_writes_the_fraction_of_a_second_to_nanosecond_resolution
    string = Horologium::Instant
      .from_civil(2025, 5, 1, 12, 0, Rational(1, 4), scale: :tai)
      .as(:iso8601, scale: :tai)

    assert_equal "2025-05-01T12:00:00.250000000", string
  end

  def test_a_fraction_that_rounds_up_carries_into_the_clock
    instant = Horologium::Instant.from_civil(2025, 5, 1, 12, 0, 59, scale: :tai)
    near_next_second = instant +
      Horologium::Duration.nanoseconds(999_999_999) +
      Horologium::Duration.nanoseconds(1)

    assert_equal "2025-05-01T12:01:00.000000000",
      near_next_second.as(:iso8601, scale: :tai)
  end

  def test_a_year_before_the_common_era_is_written_with_a_sign
    string = Horologium::Instant
      .from_civil(-44, 3, 15, scale: :tai)
      .as(:iso8601, scale: :tai)

    assert_equal "-0044-03-15T00:00:00.000000000", string
  end

  def test_a_year_after_9999_is_written_with_more_digits_and_no_sign
    string = Horologium::Instant
      .from_civil(10_000, 1, 1, scale: :tai)
      .as(:iso8601, scale: :tai)

    assert_equal "10000-01-01T00:00:00.000000000", string
  end

  def test_the_as_type_does_not_apply_and_a_string_comes_out_regardless
    instant = Horologium::Instant.from_civil(2025, 5, 1, 12, scale: :tai)

    assert_equal instant.as(:iso8601, scale: :tai),
      instant.as(:iso8601, scale: :tai, as: :rational)
  end

  def test_it_reads_a_date_and_time
    civil = Horologium::Instant
      .from_iso8601("2025-05-01T12:34:56", scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 2025, civil.year
    assert_equal 5, civil.month
    assert_equal 1, civil.day
    assert_equal 12, civil.hour
    assert_equal 34, civil.minute
    assert_equal 56, civil.second
  end

  def test_a_date_on_its_own_is_midnight
    civil = Horologium::Instant
      .from_iso8601("2025-05-01", scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 1, civil.day
    assert_equal 0, civil.hour
    assert_equal 0, civil.minute
    assert_equal 0, civil.second
  end

  def test_a_time_without_seconds_is_read
    civil = Horologium::Instant
      .from_iso8601("2025-05-01T12:34", scale: :tai)
      .as(:civil, scale: :tai)

    assert_equal 34, civil.minute
    assert_equal 0, civil.second
  end

  def test_it_reads_the_fraction_of_a_second
    civil = Horologium::Instant
      .from_iso8601(
        "2025-05-01T12:00:00.25",
        scale: :tai,
        precision: :exact
      )
      .as(:civil, scale: :tai, as: :rational)

    assert_equal Rational(1, 4), civil.second_fraction
  end

  def test_an_exact_reading_keeps_every_digit_of_the_fraction
    fraction = "123456789012345"
    civil = Horologium::Instant
      .from_iso8601(
        "2025-05-01T12:00:00.#{fraction}",
        scale: :tai,
        precision: :exact
      )
      .as(:civil, scale: :tai, as: :rational)

    assert_equal Rational(fraction.to_i, 10**fraction.length),
      civil.second_fraction
  end

  def test_the_z_designator_is_a_zero_offset
    assert_equal Horologium::Instant.from_iso8601(
      "2025-05-01T12:00:00",
      scale: :tai
    ),
      Horologium::Instant.from_iso8601("2025-05-01T12:00:00Z", scale: :tai)
  end

  def test_a_positive_offset_is_subtracted_to_reach_the_scale
    assert_equal Horologium::Instant.from_iso8601(
      "2025-05-01T12:00:00",
      scale: :tai
    ),
      Horologium::Instant.from_iso8601(
        "2025-05-01T13:00:00+01:00",
        scale: :tai
      )
  end

  def test_a_negative_offset_is_added_to_reach_the_scale
    assert_equal Horologium::Instant.from_iso8601(
      "2025-05-01T12:00:00",
      scale: :tai
    ),
      Horologium::Instant.from_iso8601(
        "2025-05-01T11:00:00-01:00",
        scale: :tai
      )
  end

  def test_it_reads_the_string_in_the_scale_it_is_given
    refute_equal Horologium::Instant.from_iso8601(
      "2025-05-01T12:00:00",
      scale: :tai
    ),
      Horologium::Instant.from_iso8601("2025-05-01T12:00:00", scale: :tt)
  end

  def test_it_reads_every_string_it_writes
    instant = Horologium::Instant.from_civil(
      2016, 12, 31, 23, 59, Rational(119, 2),
      scale: :tai,
      precision: :exact
    )
    written = instant.as(:iso8601, scale: :tai)

    assert_equal written,
      Horologium::Instant
        .from_iso8601(written, scale: :tai, precision: :exact)
        .as(:iso8601, scale: :tai)
  end

  def test_it_takes_the_precision_in_effect_by_default
    instant = Horologium.with_precision(:exact) do
      Horologium::Instant.from_iso8601("2025-05-01T12:00:00", scale: :tai)
    end

    assert_equal :exact, instant.precision
  end

  def test_a_week_date_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601("2025-W18-4", scale: :tai)
    end
  end

  def test_an_ordinal_date_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601("2025-121", scale: :tai)
    end
  end

  def test_a_bare_hour_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601("2025-05-01T12", scale: :tai)
    end
  end

  def test_a_comma_for_the_decimal_point_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601("2025-05-01T12:00:00,5", scale: :tai)
    end
  end

  def test_a_space_for_the_t_separator_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601("2025-05-01 12:00:00", scale: :tai)
    end
  end

  def test_an_offset_with_an_out_of_range_hour_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601(
        "2025-05-01T12:00:00+25:00",
        scale: :tai
      )
    end
  end

  def test_an_offset_with_an_out_of_range_minute_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601(
        "2025-05-01T12:00:00+00:99",
        scale: :tai
      )
    end
  end

  def test_a_string_that_is_not_a_date_is_refused
    error = assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_iso8601("last tuesday", scale: :tai)
    end

    assert_includes error.message, "ISO 8601"
  end

  def test_a_date_that_does_not_exist_is_refused
    assert_raises(Horologium::InvalidCivilTimeError) do
      Horologium::Instant.from_iso8601("2025-02-29", scale: :tai)
    end
  end

  def test_a_value_that_is_not_a_string_is_refused
    error = assert_raises(ArgumentError) do
      Horologium::Instant.from_iso8601(2_443_144, scale: :tai)
    end

    assert_includes error.message, "String"
  end
end
