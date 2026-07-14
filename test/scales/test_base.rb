# frozen_string_literal: true

require "test_helper"

class TestScalesBase < Minitest::Test
  def test_from_reference_is_not_implemented
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_raises(NotImplementedError) do
      Horologium::Scales::Base.from_reference(value, :standard)
    end
  end

  def test_to_reference_is_not_implemented
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_raises(NotImplementedError) do
      Horologium::Scales::Base.to_reference(value, :standard)
    end
  end

  def test_it_names_the_scale_that_must_implement_the_method
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    error = assert_raises(NotImplementedError) do
      Horologium::Scales::Base.from_reference(value, :standard)
    end

    assert_includes error.message, "Horologium::Scales::Base"
  end
end
