# frozen_string_literal: true

require "test_helper"

# A scale to register in the tests below. It is one minute ahead of TAI.
class MinuteAheadOfTAI < Horologium::Scales::Base
  OFFSET = Rational(60, 86_400)

  class << self
    def from_reference(value, precision)
      Horologium::Numeric::Precision.add(
        value,
        Horologium::Numeric::Precision.build(OFFSET, precision)
      )
    end

    def to_reference(value, precision)
      Horologium::Numeric::Precision.subtract(
        value,
        Horologium::Numeric::Precision.build(OFFSET, precision)
      )
    end
  end
end

# A scale that implements only half the contract. Registering it is refused.
class HalfBuiltScale < Horologium::Scales::Base
  def self.from_reference(value, precision)
    value
  end
end

class TestConfiguration < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_the_default_precision_is_standard_before_configuring
    assert_equal :standard, Horologium.default_precision
  end

  def test_configure_sets_the_default_precision
    Horologium.configure do |c|
      c.default_precision = :exact
    end

    assert_equal :exact, Horologium.default_precision
  end

  def test_configure_freezes_the_configuration
    configuration = Horologium.configure

    assert_predicate configuration, :frozen?
  end

  def test_the_default_precision_cannot_be_changed_after_configuring
    Horologium.configure

    assert_raises(Horologium::ConfigurationError) do
      Horologium.configuration.default_precision = :exact
    end
  end

  def test_the_leap_second_source_cannot_be_changed_after_configuring
    Horologium.configure

    assert_raises(Horologium::ConfigurationError) do
      Horologium.configuration.leap_second_source = Object.new
    end
  end

  def test_the_leap_second_source_defaults_to_the_iers_backed_one
    assert_equal Horologium::Data::LeapSeconds,
      Horologium.configuration.leap_second_source
  end

  def test_a_leap_second_source_that_cannot_answer_is_refused
    error = assert_raises(Horologium::ConfigurationError) do
      Horologium.configure do |config|
        config.leap_second_source = Object.new
      end
    end

    assert_includes error.message, "tai_utc_at"
  end

  def test_the_leap_second_horizon_defaults_to_extrapolate
    assert_equal :extrapolate, Horologium.configuration.leap_second_horizon
  end

  def test_the_leap_second_horizon_cannot_be_changed_after_configuring
    Horologium.configure

    assert_raises(Horologium::ConfigurationError) do
      Horologium.configuration.leap_second_horizon = :raise
    end
  end

  def test_an_unrecognised_leap_second_horizon_is_refused
    error = assert_raises(Horologium::ConfigurationError) do
      Horologium.configure do |config|
        config.leap_second_horizon = :ignore
      end
    end

    assert_includes error.message, "leap_second_horizon"
  end

  def test_configure_rejects_an_unrecognised_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium.configure do |c|
        c.default_precision = :fast
      end
    end
  end

  def test_current_precision_is_the_default_outside_a_scope
    Horologium.configure do |c|
      c.default_precision = :exact
    end

    assert_equal :exact, Horologium.current_precision
  end

  def test_with_precision_sets_the_precision_inside_the_block
    seen = Horologium.with_precision(:exact) do
      Horologium.current_precision
    end

    assert_equal :exact, seen
  end

  def test_with_precision_restores_the_precision_after_the_block
    Horologium.with_precision(:exact) {}

    assert_equal :standard, Horologium.current_precision
  end

  def test_with_precision_restores_the_precision_after_an_exception
    assert_raises(RuntimeError) do
      Horologium.with_precision(:exact) { raise "boom" }
    end

    assert_equal :standard, Horologium.current_precision
  end

  def test_with_precision_returns_the_block_value
    assert_equal 42, Horologium.with_precision(:exact) { 42 }
  end

  def test_with_precision_restores_the_outer_scope_when_nested
    Horologium.with_precision(:exact) do
      Horologium.with_precision(:standard) {}

      assert_equal :exact, Horologium.current_precision
    end
  end

  def test_with_precision_rejects_an_unrecognised_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium.with_precision(:fast) {}
    end
  end

  def test_with_precision_does_not_leak_into_another_fiber
    seen = nil

    Horologium.with_precision(:exact) do
      fiber = Fiber.new { seen = Horologium.current_precision }
      fiber.resume
    end

    assert_equal :standard, seen
  end

  def test_the_built_in_scales_are_registered
    assert_equal Horologium::Scales::TAI, Horologium.configuration.scale(:tai)
    assert_equal Horologium::Scales::TT, Horologium.configuration.scale(:tt)
  end

  def test_an_unregistered_scale_raises_an_unknown_scale_error
    assert_raises(Horologium::UnknownScaleError) do
      Horologium.configuration.scale(:sundial)
    end
  end

  def test_the_unknown_scale_error_carries_the_registered_scales
    error = assert_raises(Horologium::UnknownScaleError) do
      Horologium.configuration.scale(:sundial)
    end

    assert_equal %i[tai tt tdb utc], error.known_scales
  end

  def test_register_scale_adds_a_scale_an_instant_can_be_read_in
    Horologium.configure do |c|
      c.register_scale(:minute_ahead, MinuteAheadOfTAI)
    end
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_in_delta 2_443_144.500_694_444,
      instant.to(:minute_ahead).as(:julian_date),
      1e-9
  end

  def test_register_scale_replaces_a_scale_registered_under_the_same_name
    Horologium.configure do |c|
      c.register_scale(:tt, MinuteAheadOfTAI)
    end

    assert_equal MinuteAheadOfTAI, Horologium.configuration.scale(:tt)
  end

  def test_register_scale_rejects_anything_but_a_scale
    assert_raises(Horologium::ConfigurationError) do
      Horologium.configure do |c|
        c.register_scale(:sundial, :sundial)
      end
    end
  end

  def test_register_scale_rejects_a_scale_missing_half_the_contract
    assert_raises(Horologium::ConfigurationError) do
      Horologium.configure do |c|
        c.register_scale(:half_built, HalfBuiltScale)
      end
    end
  end

  def test_register_scale_rejects_a_name_that_is_not_a_symbol
    assert_raises(Horologium::ConfigurationError) do
      Horologium.configure do |c|
        c.register_scale("minute_ahead", MinuteAheadOfTAI)
      end
    end
  end

  def test_the_registered_scales_cannot_be_changed_through_scale_names
    Horologium.configuration.scale_names << :sundial

    assert_raises(Horologium::UnknownScaleError) do
      Horologium.configuration.scale(:sundial)
    end
  end

  def test_a_scale_cannot_be_registered_after_configuring
    Horologium.configure

    assert_raises(Horologium::ConfigurationError) do
      Horologium.configuration.register_scale(:minute_ahead, MinuteAheadOfTAI)
    end
  end

  def test_configure_freezes_the_configuration_when_the_block_raises
    assert_raises(Horologium::ConfigurationError) do
      Horologium.configure do |c|
        c.register_scale(:sundial, :sundial)
      end
    end

    assert_predicate Horologium.configuration, :frozen?
  end

  def test_configure_freezes_the_scale_registry
    Horologium.configure

    assert_raises(Horologium::ConfigurationError) do
      Horologium.configuration.register_scale(:minute_ahead, MinuteAheadOfTAI)
    end
  end

  def test_the_scale_names_list_the_registered_scales
    assert_equal %i[tai tt tdb utc], Horologium.configuration.scale_names
  end
end
