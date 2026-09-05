# frozen_string_literal: true

require "test_helper"

class TestScaleReading < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_is_frozen
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_predicate reading, :frozen?
  end

  def test_it_knows_the_scale_it_reads_in
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_equal :tt, reading.scale
  end

  def test_it_keeps_the_precision_of_the_instant_it_came_from
    instant = Horologium::Instant.from_julian_date(
      2_443_144.5,
      scale: :tai,
      precision: :exact
    )

    assert_equal :exact, instant.to(:tt).precision
  end

  def test_it_reads_as_a_float_by_default
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_in_delta 2_443_144.500_372_5,
      reading.as(:julian_date),
      1e-9
  end

  def test_it_reads_as_a_rational
    instant = Horologium::Instant.from_julian_date(
      2_443_144.5,
      scale: :tai,
      precision: :exact
    )

    assert_equal Rational(24_431_445_003_725, 10_000_000),
      instant.to(:tt).as(:julian_date, as: :rational)
  end

  def test_it_reads_as_a_two_part_float
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_instance_of Horologium::Numeric::TwoPartFloat,
      reading.as(:julian_date, as: :two_part)
  end

  def test_it_rejects_an_unknown_representation
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_raises(Horologium::UnknownRepresentationError) do
      reading.as(:sundial)
    end
  end

  def test_it_rejects_an_unknown_output_type
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    assert_raises(Horologium::UnknownOutputError) do
      reading.as(:julian_date, as: :decimal)
    end
  end

  def test_a_value_that_does_not_match_its_precision_is_refused
    assert_raises(ArgumentError) do
      Horologium::ScaleReading.new(
        :tt,
        Horologium::Numeric::Exact.new(2_443_144.5),
        :standard,
        Horologium::Scales::TT
      )
    end
  end

  def test_the_unknown_representation_error_carries_the_known_ones
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    error = assert_raises(Horologium::UnknownRepresentationError) do
      reading.as(:sundial)
    end

    assert_equal %i[julian_date modified_julian_date civil iso8601],
      error.known_representations
  end

  def test_it_reads_as_a_modified_julian_date
    reading = Horologium::Instant
      .from_julian_date(2_460_796.5, scale: :tai)
      .to(:tai)

    assert_in_delta 60_796.0, reading.as(:modified_julian_date), 1e-9
  end

  # Equality, so a reading behaves as the value object it is.

  def test_two_readings_of_the_same_moment_in_the_same_scale_are_equal
    assert_equal Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt),
      Horologium::Instant
        .from_julian_date(2_443_144.5, scale: :tai)
        .to(:tt)
  end

  def test_readings_of_the_same_moment_in_different_scales_are_not_equal
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    refute_equal instant.to(:tai), instant.to(:tt)
  end

  def test_readings_of_different_moments_are_not_equal
    refute_equal Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt),
      Horologium::Instant
        .from_julian_date(2_443_145.5, scale: :tai)
        .to(:tt)
  end

  def test_a_reading_is_not_equal_to_a_value_of_another_type
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tt)

    refute_equal reading, Object.new
  end

  def test_equality_ignores_the_precision
    assert_equal Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tai),
      Horologium::Instant
        .from_julian_date(2_443_144.5, scale: :tai, precision: :exact)
        .to(:tai)
  end

  def test_eql_takes_the_precision_into_account
    standard = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tai)
    exact = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai, precision: :exact)
      .to(:tai)

    refute standard.eql?(exact)
  end

  def test_it_works_as_a_hash_key
    readings = {
      Horologium::Instant
        .from_julian_date(2_443_144.5, scale: :tai)
        .to(:tt) => :found
    }

    assert_equal :found, readings[
      Horologium::Instant
        .from_julian_date(2_443_144.5, scale: :tai)
        .to(:tt)
    ]
  end

  def test_inspect_shows_the_scale_the_precision_and_the_provenance
    reading = Horologium::Instant
      .from_julian_date(2_443_144.5, scale: :tai)
      .to(:tai)

    assert_equal "#<Horologium::ScaleReading 2443144.5 JD in tai " \
      "(standard, measured)>",
      reading.inspect
  end

  def test_provenance_comes_from_the_scale_that_took_the_reading
    reading = Horologium::Instant
      .from_julian_date(2_500_000.5, scale: :tai)
      .to(:utc)
    replacement = Class.new(Horologium::Scales::Base) do
      def self.from_reference(value, _precision)
        value
      end

      def self.to_reference(value, _precision)
        value
      end

      def self.provenance(_value)
        :measured
      end
    end
    Horologium.configure { |config| config.register_scale(:utc, replacement) }

    assert_equal :extrapolated, reading.provenance
  end
end
