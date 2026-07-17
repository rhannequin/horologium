# frozen_string_literal: true

require "test_helper"

class TestScalesTAI < Minitest::Test
  def test_reading_the_reference_in_tai_returns_the_same_value
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_equal value,
      Horologium::Scales::TAI.from_reference(value, :standard)
  end

  def test_reading_tai_back_into_the_reference_returns_the_same_value
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_equal value, Horologium::Scales::TAI.to_reference(value, :standard)
  end

  def test_it_returns_the_same_exact_value
    value = Horologium::Numeric::Exact.new(Rational(4_886_289, 2))

    assert_equal value, Horologium::Scales::TAI.from_reference(value, :exact)
  end

  def test_an_instant_reads_in_tai_as_the_julian_date_it_was_built_from
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

    assert_in_delta 2_460_000.5, instant.to(:tai).as(:julian_date)
  end
end
