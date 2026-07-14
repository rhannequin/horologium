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

  def test_unknown_precision_error_carries_the_known_precisions
    error = Horologium::UnknownPrecisionError.new(:fast, %i[standard exact])

    assert_equal %i[standard exact], error.known_precisions
  end

  def test_unknown_precision_error_names_the_given_precision
    error = Horologium::UnknownPrecisionError.new(:fast, %i[standard exact])

    assert_includes error.message, ":fast"
  end
end
