# frozen_string_literal: true

require "test_helper"

class TestRepresentationsModifiedJulianDate < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_renders_the_julian_date_from_the_later_origin
    reading = Horologium::Instant
      .from_julian_date(2_460_796.5, scale: :tai)
      .to(:tai)

    assert_in_delta 60_796.0,
      Horologium::Representations::ModifiedJulianDate.render(reading, :float),
      1e-9
  end

  def test_it_renders_an_exact_reading_with_nothing_dropped
    reading = Horologium::Instant
      .from_modified_julian_date(
        "60796.052272",
        scale: :tai,
        precision: :exact
      )
      .to(:tai)

    assert_equal Rational(60_796_052_272, 1_000_000),
      Horologium::Representations::ModifiedJulianDate.render(
        reading,
        :rational
      )
  end

  def test_it_renders_as_a_two_part_float
    reading = Horologium::Instant
      .from_julian_date(2_460_796.5, scale: :tai)
      .to(:tai)

    rendered = Horologium::Representations::ModifiedJulianDate.render(
      reading,
      :two_part
    )

    assert_instance_of Horologium::Numeric::TwoPartFloat, rendered
    assert_in_delta 60_796.0, rendered.to_f, 1e-9
  end

  def test_it_rejects_an_unknown_output_type
    reading = Horologium::Instant
      .from_julian_date(2_460_796.5, scale: :tai)
      .to(:tai)

    error = assert_raises(Horologium::UnknownOutputError) do
      Horologium::Representations::ModifiedJulianDate.render(reading, :decimal)
    end

    assert_equal %i[float rational two_part], error.known_outputs
  end

  def test_it_reads_the_scale_the_instant_is_read_in
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_in_delta 43_144.000_372_5,
      Horologium::Representations::ModifiedJulianDate.render(reading, :float),
      1e-9
  end

  def test_it_parses_a_modified_julian_date_as_a_julian_date
    parsed = Horologium::Representations::ModifiedJulianDate.parse(
      60_796.0,
      nil,
      Horologium::Scales::TAI,
      :exact
    )

    assert_equal Rational(24_607_965, 10), parsed.to_r
  end

  def test_it_parses_a_string_exactly
    parsed = Horologium::Representations::ModifiedJulianDate.parse(
      "60796.052272",
      nil,
      Horologium::Scales::TAI,
      :exact
    )

    assert_equal Rational(60_796_052_272, 1_000_000) +
      Horologium::Representations::ModifiedJulianDate::
        DAYS_AFTER_JULIAN_DATE_ORIGIN,
      parsed.to_r
  end

  def test_it_parses_two_parts
    parsed = Horologium::Representations::ModifiedJulianDate.parse(
      60_796.0,
      0.5,
      Horologium::Scales::TAI,
      :standard
    )

    assert_in_delta 2_460_797.0, parsed.to_f, 1e-9
  end

  def test_it_rejects_an_unknown_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Representations::ModifiedJulianDate.parse(
        60_796.0,
        nil,
        Horologium::Scales::TAI,
        :fast
      )
    end
  end

  def test_a_modified_julian_date_is_the_julian_date_minus_the_two_origins_gap
    assert_equal Rational(4_800_001, 2),
      Horologium::Representations::ModifiedJulianDate::
        DAYS_AFTER_JULIAN_DATE_ORIGIN
  end
end
