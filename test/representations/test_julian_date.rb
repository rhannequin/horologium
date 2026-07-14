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
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_equal :tt, reading.scale
    assert_in_delta 2_443_144.500_372_5,
      Horologium::Representations::JulianDate.render(reading, :float),
      1e-9
  end

  def test_it_rejects_an_unknown_output_type
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tai)

    error = assert_raises(Horologium::UnknownOutputError) do
      Horologium::Representations::JulianDate.render(reading, :decimal)
    end

    assert_includes error.message, ":decimal"
    assert_equal %i[float rational two_part], error.known_outputs
  end
end
