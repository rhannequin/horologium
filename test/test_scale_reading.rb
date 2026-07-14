# frozen_string_literal: true

require "test_helper"

class TestScaleReading < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_is_frozen
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_predicate reading, :frozen?
  end

  def test_it_knows_the_scale_it_reads_in
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_equal :tt, reading.scale
  end

  def test_it_keeps_the_precision_of_the_instant_it_came_from
    instant = Horologium::Instant.from_tai_julian_date(
      2_443_144.5,
      precision: :exact
    )

    assert_equal :exact, instant.to(:tt).precision
  end

  def test_it_reads_as_a_float_by_default
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_in_delta 2_443_144.500_372_5,
      reading.as(:julian_date),
      1e-9
  end

  def test_it_reads_as_a_rational
    instant = Horologium::Instant.from_tai_julian_date(
      2_443_144.5,
      precision: :exact
    )

    assert_equal Rational(24_431_445_003_725, 10_000_000),
      instant.to(:tt).as(:julian_date, as: :rational)
  end

  def test_it_reads_as_a_two_part_float
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_instance_of Horologium::Numeric::TwoPartFloat,
      reading.as(:julian_date, as: :two_part)
  end

  def test_it_rejects_an_unknown_representation
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_raises(Horologium::UnknownRepresentationError) do
      reading.as(:sundial)
    end
  end

  def test_it_rejects_an_unknown_output_type
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    assert_raises(Horologium::UnknownOutputError) do
      reading.as(:julian_date, as: :decimal)
    end
  end

  def test_a_value_that_does_not_match_its_precision_is_refused
    assert_raises(ArgumentError) do
      Horologium::ScaleReading.new(
        :tt,
        Horologium::Numeric::Exact.new(2_443_144.5),
        :standard
      )
    end
  end

  def test_the_unknown_representation_error_carries_the_known_ones
    reading = Horologium::Instant.from_tai_julian_date(2_443_144.5).to(:tt)

    error = assert_raises(Horologium::UnknownRepresentationError) do
      reading.as(:sundial)
    end

    assert_equal [:julian_date], error.known_representations
  end
end
