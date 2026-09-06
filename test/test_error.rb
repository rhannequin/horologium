# frozen_string_literal: true

require "test_helper"

class TestError < Minitest::Test
  def test_configuration_error_descends_from_the_base_error
    assert_operator Horologium::ConfigurationError, :<, Horologium::Error
  end

  def test_unknown_precision_error_descends_from_the_base_error
    assert_operator Horologium::UnknownPrecisionError, :<, Horologium::Error
  end

  def test_dimensional_error_descends_from_the_base_error
    assert_operator Horologium::DimensionalError, :<, Horologium::Error
  end

  def test_parse_error_descends_from_the_base_error
    assert_operator Horologium::ParseError, :<, Horologium::Error
  end

  def test_unknown_precision_error_carries_the_known_precisions
    error = Horologium::UnknownPrecisionError.new(:fast, %i[standard exact])

    assert_equal %i[standard exact], error.known_precisions
  end

  def test_unknown_precision_error_names_the_given_precision
    error = Horologium::UnknownPrecisionError.new(:fast, %i[standard exact])

    assert_includes error.message, ":fast"
  end

  def test_unknown_scale_error_descends_from_the_base_error
    assert_operator Horologium::UnknownScaleError, :<, Horologium::Error
  end

  def test_unknown_scale_error_names_the_given_scale
    error = Horologium::UnknownScaleError.new(:sundial, %i[tai tt])

    assert_includes error.message, ":sundial"
  end

  def test_unknown_representation_error_descends_from_the_base_error
    assert_operator Horologium::UnknownRepresentationError, :<,
      Horologium::Error
  end

  def test_unknown_representation_error_names_the_given_representation
    error = Horologium::UnknownRepresentationError.new(
      :sundial,
      %i[julian_date]
    )

    assert_includes error.message, ":sundial"
  end

  def test_unknown_output_error_descends_from_the_base_error
    assert_operator Horologium::UnknownOutputError, :<, Horologium::Error
  end

  def test_unknown_output_error_carries_the_known_outputs
    error = Horologium::UnknownOutputError.new(:decimal, %i[float rational])

    assert_equal %i[float rational], error.known_outputs
  end

  # The point of the hierarchy is that a caller can rescue the library as a
  # unit, which only holds if nothing escapes it. A number that is not finite,
  # or not a number at all, used to come back as Ruby's own FloatDomainError
  # or NoMethodError, which Horologium::Error does not cover.
  HOSTILE = [
    nil, Float::NAN, Float::INFINITY, -Float::INFINITY, [], {}, :sym,
    Object.new, "", "x", 10**1000, -(10**1000), Rational(10**1000, 3),
    true, false
  ].freeze

  def test_no_input_escapes_the_error_hierarchy
    escaped = []

    HOSTILE.each do |value|
      entry_points(value).each do |name, block|
        block.call
      rescue Horologium::Error, ZeroDivisionError
        next
      rescue => e
        escaped << "#{name}(#{value.inspect[0, 14]}) raised #{e.class}"
      end
    end

    assert_empty escaped
  end

  def test_a_value_that_is_not_a_finite_number_is_refused
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Duration.seconds(Float::INFINITY)
    end
  end

  def test_a_value_that_is_not_a_number_is_refused
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Duration.days(:soon)
    end
  end

  def test_invalid_value_error_is_one_of_the_library_errors
    assert_operator Horologium::InvalidValueError, :<, Horologium::Error
  end

  private

  def an_instant
    Horologium::Instant.from_julian_date(2_451_545.0, scale: :tai)
  end

  # Every way a value reaches the library, so the claim the hierarchy makes is
  # checked against the whole surface rather than a sample of it.
  #
  # @param value [Object] the value to push through each one
  # @return [Hash{String => Proc}]
  def entry_points(value)
    instant_entry_points(value)
      .merge(duration_entry_points(value))
      .merge(numeric_entry_points(value))
  end

  def instant_entry_points(value)
    i = Horologium::Instant
    {
      "from_julian_date" => -> { i.from_julian_date(value, scale: :tai) },
      "from_julian_date high" => -> {
        i.from_julian_date(value, 0.0, scale: :tai)
      },
      "from_julian_date low" => -> {
        i.from_julian_date(2_451_545.0, value, scale: :tai)
      },
      "from_modified_julian_date" => -> {
        i.from_modified_julian_date(value, scale: :tai)
      },
      "from_modified_julian_date low" => -> {
        i.from_modified_julian_date(51_544.0, value, scale: :tai)
      },
      "from_iso8601" => -> { i.from_iso8601(value, scale: :tai) },
      "from_civil year" => -> { i.from_civil(value, 1, 1, scale: :tai) },
      "from_civil month" => -> { i.from_civil(2000, value, 1, scale: :tai) },
      "from_civil day" => -> { i.from_civil(2000, 1, value, scale: :tai) },
      "from_civil hour" => -> { i.from_civil(2000, 1, 1, value, scale: :tai) },
      "from_civil minute" => -> {
        i.from_civil(2000, 1, 1, 0, value, scale: :tai)
      },
      "from_civil second" => -> {
        i.from_civil(2000, 1, 1, 0, 0, value, scale: :tai)
      },
      "from_utc second" => -> { i.from_utc(2000, 1, 1, 0, 0, value) },
      "from_ut1 second" => -> { i.from_ut1(2000, 1, 1, 0, 0, value) },
      "Instant#+" => -> { an_instant + value },
      "Instant#-" => -> { an_instant - value },
      "Instant#to" => -> { an_instant.to(value) },
      "Instant#as representation" => -> { an_instant.as(value, scale: :tai) },
      "Instant#as output" => -> {
        an_instant.as(:julian_date, scale: :tai, as: value)
      },
      "Instant#equal_within?" => -> {
        an_instant.equal_within?(an_instant, value)
      }
    }
  end

  def duration_entry_points(value)
    d = Horologium::Duration
    {
      "Duration.seconds" => -> { d.seconds(value) },
      "Duration.minutes" => -> { d.minutes(value) },
      "Duration.hours" => -> { d.hours(value) },
      "Duration.days" => -> { d.days(value) },
      "Duration.nanoseconds" => -> { d.nanoseconds(value) },
      "Duration.julian_years" => -> { d.julian_years(value) },
      "Duration.julian_centuries" => -> { d.julian_centuries(value) },
      "Duration#+" => -> { d.seconds(1) + value },
      "Duration#-" => -> { d.seconds(1) - value }
    }
  end

  def numeric_entry_points(value)
    p = Horologium::Numeric::Precision
    t = Horologium::Numeric::TwoPartFloat
    e = Horologium::Numeric::Exact
    one = p.build(1, :standard)
    {
      "Precision.build standard" => -> { p.build(value, :standard) },
      "Precision.build exact" => -> { p.build(value, :exact) },
      "Precision.build_each" => -> { p.build_each(value) },
      "Precision.number!" => -> { p.number!(value) },
      "Precision.finite_float!" => -> { p.finite_float!(value) },
      "Precision.add" => -> { p.add(one, value) },
      "Precision.subtract" => -> { p.subtract(one, value) },
      "Precision.compare" => -> { p.compare(one, value) },
      "Precision.coerce" => -> { p.coerce(value, to: :exact) },
      "TwoPartFloat.from_real" => -> { t.from_real(value) },
      "TwoPartFloat.normalize high" => -> { t.normalize(value, 0.0) },
      "TwoPartFloat.normalize low" => -> { t.normalize(1.0, value) },
      "TwoPartFloat#*" => -> { t.from_real(1.0) * value },
      "TwoPartFloat#/" => -> { t.from_real(1.0) / value },
      "Exact.new" => -> { e.new(value) },
      "Exact#*" => -> { e.new(1) * value },
      "Exact#/" => -> { e.new(1) / value }
    }
  end
end
