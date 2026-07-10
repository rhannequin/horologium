# frozen_string_literal: true

require "test_helper"

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
end
