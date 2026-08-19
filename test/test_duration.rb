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

  # Arithmetic between durations.

  def test_it_adds_another_duration
    assert_equal Horologium::Duration.seconds(42),
      Horologium::Duration.seconds(30) + Horologium::Duration.seconds(12)
  end

  def test_it_subtracts_another_duration
    assert_equal Horologium::Duration.seconds(30),
      Horologium::Duration.seconds(42) - Horologium::Duration.seconds(12)
  end

  def test_subtracting_a_longer_duration_runs_backwards
    assert_equal Horologium::Duration.seconds(-12),
      Horologium::Duration.seconds(30) - Horologium::Duration.seconds(42)
  end

  def test_adding_keeps_standard_when_both_are_standard
    sum = Horologium::Duration.seconds(1) + Horologium::Duration.seconds(2)

    assert_equal :standard, sum.precision
  end

  def test_adding_an_exact_duration_promotes_the_result
    sum = Horologium::Duration.seconds(1) +
      Horologium::Duration.seconds(2, precision: :exact)

    assert_equal :exact, sum.precision
  end

  def test_subtracting_an_exact_duration_promotes_the_result
    difference = Horologium::Duration.seconds(2) -
      Horologium::Duration.seconds(1, precision: :exact)

    assert_equal :exact, difference.precision
  end

  def test_it_refuses_to_add_anything_but_a_duration
    error = assert_raises(Horologium::DimensionalError) do
      Horologium::Duration.seconds(1) +
        Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)
    end

    assert_includes error.message, "only a Duration combines with a Duration"
  end

  def test_it_refuses_to_subtract_anything_but_a_duration
    error = assert_raises(Horologium::DimensionalError) do
      Horologium::Duration.seconds(1) - 5
    end

    assert_includes error.message, "only a Duration combines with a Duration"
  end

  def test_it_negates
    assert_equal Horologium::Duration.seconds(-3),
      -Horologium::Duration.seconds(3)
  end

  def test_negating_keeps_the_precision
    negated = -Horologium::Duration.seconds(3, precision: :exact)

    assert_equal :exact, negated.precision
  end

  # Asking a duration about itself.

  def test_zero_is_true_for_no_time_at_all
    assert_predicate Horologium::Duration.seconds(0), :zero?
  end

  def test_zero_is_false_for_a_length
    refute_predicate Horologium::Duration.seconds(1), :zero?
  end

  def test_negative_is_true_running_backwards
    assert_predicate Horologium::Duration.seconds(-1), :negative?
  end

  def test_negative_is_false_running_forwards
    refute_predicate Horologium::Duration.seconds(1), :negative?
  end

  def test_positive_is_true_running_forwards
    assert_predicate Horologium::Duration.seconds(1), :positive?
  end

  def test_positive_is_false_running_backwards
    refute_predicate Horologium::Duration.seconds(-1), :positive?
  end

  def test_to_r_reads_the_seconds_exactly
    assert_equal Rational(86_400), Horologium::Duration.days(1).to_r
  end

  def test_to_f_reads_the_seconds_as_a_float
    assert_in_delta 86_400.0, Horologium::Duration.days(1).to_f
  end

  def test_inspect_shows_the_seconds_and_the_precision
    duration = Horologium::Duration.seconds(3600)

    assert_equal "#<Horologium::Duration 3600.0 s (standard)>",
      duration.inspect
  end
end
