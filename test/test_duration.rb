# frozen_string_literal: true

require "test_helper"

class TestDuration < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_is_frozen
    assert_predicate Horologium::Duration.seconds(1), :frozen?
  end

  def test_days_are_a_fixed_number_of_si_seconds
    assert_equal Horologium::Duration.seconds(86_400),
      Horologium::Duration.days(1)
  end

  def test_nanoseconds_are_a_fraction_of_a_second
    assert_equal Horologium::Duration.seconds(1),
      Horologium::Duration.nanoseconds(1_000_000_000)
  end

  def test_it_orders_durations_by_length
    assert_operator Horologium::Duration.seconds(1), :<,
      Horologium::Duration.seconds(2)
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::Duration.seconds(1), Object.new
  end

  def test_it_sorts_by_length
    durations = [
      Horologium::Duration.seconds(3),
      Horologium::Duration.seconds(1),
      Horologium::Duration.seconds(2)
    ]

    assert_equal [
      Horologium::Duration.seconds(1),
      Horologium::Duration.seconds(2),
      Horologium::Duration.seconds(3)
    ], durations.sort
  end

  def test_abs_leaves_a_positive_duration_unchanged
    assert_equal Horologium::Duration.seconds(3),
      Horologium::Duration.seconds(3).abs
  end

  def test_abs_negates_a_negative_duration
    assert_equal Horologium::Duration.seconds(3),
      Horologium::Duration.seconds(-3).abs
  end

  def test_abs_keeps_the_precision
    duration = Horologium::Duration.seconds(-3, precision: :exact)

    assert_equal :exact, duration.abs.precision
  end

  def test_abs_negates_an_exact_negative_duration
    assert_equal Horologium::Duration.seconds(3, precision: :exact),
      Horologium::Duration.seconds(-3, precision: :exact).abs
  end

  def test_new_rejects_a_value_that_does_not_match_the_precision
    assert_raises(ArgumentError) do
      Horologium::Duration.new(Horologium::Numeric::Exact.new(1), :standard)
    end
  end

  def test_it_is_equal_across_precisions_by_length
    assert_equal Horologium::Duration.seconds(1, precision: :standard),
      Horologium::Duration.seconds(1, precision: :exact)
  end

  def test_it_is_not_eql_across_precisions
    refute_operator Horologium::Duration.seconds(1, precision: :standard),
      :eql?, Horologium::Duration.seconds(1, precision: :exact)
  end

  def test_it_is_eql_to_the_same_length_and_precision
    assert_operator Horologium::Duration.seconds(1, precision: :exact),
      :eql?, Horologium::Duration.seconds(1, precision: :exact)
  end

  def test_durations_of_different_precisions_are_distinct_hash_keys
    store = {
      Horologium::Duration.seconds(1, precision: :standard) => :standard,
      Horologium::Duration.seconds(1, precision: :exact) => :exact
    }

    assert_equal 2, store.size
  end

  def test_it_takes_the_precision_in_effect_by_default
    precision = Horologium.with_precision(:exact) do
      Horologium::Duration.seconds(1).precision
    end

    assert_equal :exact, precision
  end

  def test_nanoseconds_stay_exact_in_the_exact_precision
    fraction = Horologium::Duration.seconds(
      Rational(1, 1_000_000_000),
      precision: :exact
    )

    assert_equal fraction,
      Horologium::Duration.nanoseconds(1, precision: :exact)
  end

  def test_it_rejects_an_unknown_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Duration.seconds(1, precision: :fast)
    end
  end

  def test_new_rejects_an_unknown_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Duration.new(Horologium::Numeric::Exact.new(1), :fast)
    end
  end

  def test_seconds_retains_precision_a_single_float_would_lose
    count = 2**53 + 1

    assert_equal count, Horologium::Duration.seconds(count).value.to_r
  end
end
