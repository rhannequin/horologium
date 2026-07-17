# frozen_string_literal: true

require "test_helper"

class TestRepresentationsJulianDate < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_renders_a_standard_reading_as_a_float
    reading = Horologium::ScaleReading.new(
      :tai,
      Horologium::Numeric::TwoPartFloat.new(2_443_144.5, 3.725e-4),
      :standard
    )

    assert_in_delta 2_443_144.500_372_5,
      Horologium::Representations::JulianDate.render(reading, :float),
      1e-9
  end

  def test_it_renders_an_exact_reading_as_a_float
    reading = Horologium::ScaleReading.new(
      :tai,
      Horologium::Numeric::Exact.new(
        Rational(24_431_445_003_725, 10_000_000)
      ),
      :exact
    )

    assert_in_delta 2_443_144.500_372_5,
      Horologium::Representations::JulianDate.render(reading, :float),
      1e-9
  end

  def test_it_renders_an_exact_reading_as_a_rational_with_nothing_dropped
    reading = Horologium::ScaleReading.new(
      :tai,
      Horologium::Numeric::Exact.new(
        Rational(24_431_445_003_725, 10_000_000)
      ),
      :exact
    )

    assert_equal Rational(24_431_445_003_725, 10_000_000),
      Horologium::Representations::JulianDate.render(reading, :rational)
  end

  def test_it_renders_a_standard_reading_as_the_two_part_float_it_holds
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5, 3.725e-4)
    reading = Horologium::ScaleReading.new(:tai, value, :standard)

    assert_same value,
      Horologium::Representations::JulianDate.render(reading, :two_part)
  end

  def test_it_renders_an_exact_reading_as_a_two_part_float
    value = Horologium::Numeric::Exact.new(
      Rational(24_431_445_003_725, 10_000_000)
    )
    reading = Horologium::ScaleReading.new(:tai, value, :exact)

    rendered = Horologium::Representations::JulianDate.render(
      reading,
      :two_part
    )

    assert_instance_of Horologium::Numeric::TwoPartFloat, rendered
    assert_operator (rendered.to_r - value.to_r).abs, :<,
      Rational(1, 86_400 * 1_000_000_000)
  end

  def test_it_is_given_the_reading_so_it_can_see_the_scale
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_equal :tt, reading.scale
    assert_in_delta 2_443_144.500_372_5,
      Horologium::Representations::JulianDate.render(reading, :float),
      1e-9
  end

  def test_it_rejects_an_unknown_output_type
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tai)

    error = assert_raises(Horologium::UnknownOutputError) do
      Horologium::Representations::JulianDate.render(reading, :decimal)
    end

    assert_includes error.message, ":decimal"
    assert_equal %i[float rational two_part], error.known_outputs
  end

  def test_it_parses_a_string_exactly
    parsed = Horologium::Representations::JulianDate.parse(
      "2456463.052272",
      nil,
      :exact
    )

    assert_equal Rational(2_456_463_052_272, 1_000_000), parsed.to_r
  end

  def test_it_parses_a_string_at_the_standard_precision_across_two_floats
    parsed = Horologium::Representations::JulianDate.parse(
      "2456463.052272",
      nil,
      :standard
    )

    assert_instance_of Horologium::Numeric::TwoPartFloat, parsed
    assert_operator (
      parsed.to_r - Rational(2_456_463_052_272, 1_000_000)
    ).abs, :<, Rational(1, 86_400 * 1_000_000_000)
  end

  def test_it_parses_a_rational_exactly
    parsed = Horologium::Representations::JulianDate.parse(
      Rational(2_456_463_052_272, 1_000_000),
      nil,
      :exact
    )

    assert_equal Rational(2_456_463_052_272, 1_000_000), parsed.to_r
  end

  def test_it_parses_an_integer
    parsed = Horologium::Representations::JulianDate.parse(
      2_456_463,
      nil,
      :exact
    )

    assert_equal Rational(2_456_463), parsed.to_r
  end

  def test_it_normalizes_a_float_onto_the_integer_day_grid
    parsed = Horologium::Representations::JulianDate.parse(
      2_456_463.9,
      nil,
      :standard
    )

    assert_equal Horologium::Numeric::TwoPartFloat.normalize(2_456_463.9),
      parsed
  end

  def test_it_normalizes_two_parts_onto_the_integer_day_grid
    parsed = Horologium::Representations::JulianDate.parse(
      2_456_463.0,
      0.75,
      :standard
    )

    assert_equal Horologium::Numeric::TwoPartFloat.normalize(
      2_456_463.0,
      0.75
    ), parsed
  end

  def test_it_keeps_both_parts_of_a_two_part_julian_date_at_the_exact_precision
    parsed = Horologium::Representations::JulianDate.parse(
      2_456_463.0,
      1e-16,
      :exact
    )

    assert_equal Rational(2_456_463.0) + Rational(1e-16), parsed.to_r
  end

  def test_it_rejects_a_string_that_does_not_spell_a_julian_date
    error = assert_raises(Horologium::ParseError) do
      Horologium::Representations::JulianDate.parse("yesterday", nil, :exact)
    end

    assert_includes error.message, "yesterday"
  end

  def test_it_rejects_a_value_it_cannot_read_as_a_julian_date
    error = assert_raises(ArgumentError) do
      Horologium::Representations::JulianDate.parse(nil, nil, :standard)
    end

    assert_includes error.message, "NilClass"
  end

  def test_it_rejects_a_part_that_is_not_a_float
    error = assert_raises(ArgumentError) do
      Horologium::Representations::JulianDate.parse(
        2_456_463.0,
        Rational(1, 2),
        :standard
      )
    end

    assert_includes error.message, "Rational"
  end

  def test_it_rejects_an_unknown_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Representations::JulianDate.parse(2_456_463.0, nil, :fast)
    end
  end
end
