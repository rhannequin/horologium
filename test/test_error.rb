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
  HOSTILE = [nil, Float::NAN, Float::INFINITY, -Float::INFINITY, [], {}, :sym]

  def test_no_input_escapes_the_error_hierarchy
    escaped = []

    HOSTILE.each do |value|
      entry_points(value).each do |name, block|
        block.call
      rescue Horologium::Error
        next
      rescue => e
        escaped << "#{name}(#{value.inspect}) raised #{e.class}"
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

  # @param value [Object] the value to push through each entry point
  # @return [Hash{String => Proc}]
  def entry_points(value)
    {
      "from_julian_date" => -> {
        Horologium::Instant.from_julian_date(value, scale: :tai)
      },
      "from_modified_julian_date" => -> {
        Horologium::Instant.from_modified_julian_date(value, scale: :tai)
      },
      "from_iso8601" => -> {
        Horologium::Instant.from_iso8601(value, scale: :tai)
      },
      "from_civil year" => -> {
        Horologium::Instant.from_civil(value, 1, 1, scale: :tai)
      },
      "from_civil second" => -> {
        Horologium::Instant.from_civil(2000, 1, 1, 0, 0, value, scale: :tai)
      },
      "Duration.seconds" => -> { Horologium::Duration.seconds(value) },
      "Duration.days" => -> { Horologium::Duration.days(value) },
      "Duration.julian_years" => -> {
        Horologium::Duration.julian_years(value)
      }
    }
  end
end
