# frozen_string_literal: true

require "test_helper"

class TestTwoPartFloat < Minitest::Test
  def test_it_is_frozen
    two_part_float = Horologium::Numeric::TwoPartFloat.new(1.0, 0.5)

    assert_predicate two_part_float, :frozen?
  end

  def test_the_low_part_defaults_to_zero
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.0, 0.0),
      Horologium::Numeric::TwoPartFloat.new(1.0)
  end

  def test_it_is_equal_to_another_instance_with_the_same_parts
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.0, 0.5),
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.5)
  end

  def test_it_is_not_equal_to_an_instance_with_a_different_part
    refute_equal Horologium::Numeric::TwoPartFloat.new(1.0, 0.5),
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.25)
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::Numeric::TwoPartFloat.new(1.0, 0.5), Object.new
  end

  def test_it_is_eql_to_an_instance_with_the_same_parts
    assert_operator Horologium::Numeric::TwoPartFloat.new(1.0, 0.5), :eql?,
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.5)
  end

  def test_it_is_not_eql_to_an_instance_with_a_different_part
    refute_operator Horologium::Numeric::TwoPartFloat.new(1.0, 0.5), :eql?,
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.25)
  end

  def test_equal_instances_share_the_same_hash
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.0, 0.5).hash,
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.5).hash
  end

  def test_it_can_be_used_as_a_hash_key
    store = {Horologium::Numeric::TwoPartFloat.new(1.0, 0.5) => :value}

    assert_equal :value, store[Horologium::Numeric::TwoPartFloat.new(1.0, 0.5)]
  end

  def test_two_sum_reconstructs_the_exact_sum_of_its_operands
    sum, error = Horologium::Numeric::TwoPartFloat.two_sum(0.1, 0.2)

    assert_equal Rational(0.1) + Rational(0.2), Rational(sum) + Rational(error)
  end

  def test_two_sum_leaves_no_error_for_exactly_representable_operands
    assert_equal [3.0, 0.0], Horologium::Numeric::TwoPartFloat.two_sum(1.0, 2.0)
  end

  def test_two_diff_reconstructs_the_exact_difference_of_its_operands
    difference, error = Horologium::Numeric::TwoPartFloat.two_diff(1.0, 1e-16)

    assert_equal Rational(1.0) - Rational(1e-16),
      Rational(difference) + Rational(error)
  end

  def test_two_diff_captures_the_error_a_plain_subtraction_would_lose
    assert_equal [1e16, -1.0], Horologium::Numeric::TwoPartFloat.two_diff(1e16, 1.0)
  end

  def test_fast_two_sum_reconstructs_the_exact_sum_when_the_first_operand_dominates
    assert_equal [1.0, 1e-16], Horologium::Numeric::TwoPartFloat.fast_two_sum(1.0, 1e-16)
  end

  def test_addition_adds_two_ordinary_values
    assert_equal Horologium::Numeric::TwoPartFloat.new(3.75),
      Horologium::Numeric::TwoPartFloat.new(1.5) + Horologium::Numeric::TwoPartFloat.new(2.25)
  end

  def test_addition_retains_precision_a_plain_float_would_lose
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16),
      Horologium::Numeric::TwoPartFloat.new(1.0) + Horologium::Numeric::TwoPartFloat.new(1e-16)
  end

  def test_subtraction_subtracts_two_ordinary_values
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.25),
      Horologium::Numeric::TwoPartFloat.new(1.5) - Horologium::Numeric::TwoPartFloat.new(0.25)
  end

  def test_subtraction_retains_precision_a_plain_float_would_lose
    assert_equal Horologium::Numeric::TwoPartFloat.new(1e-16), (
      Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16) -
        Horologium::Numeric::TwoPartFloat.new(1.0)
    )
  end

  def test_it_returns_the_exact_sum_of_its_parts_as_a_rational
    assert_equal Rational(7, 4),
      Horologium::Numeric::TwoPartFloat.new(1.5, 0.25).to_r
  end

  def test_to_r_keeps_precision_a_plain_float_would_lose
    assert_equal 1.to_r + Rational(1e-16),
      Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16).to_r
  end

  def test_to_r_handles_a_negative_low_part
    assert_equal Rational(7, 4),
      Horologium::Numeric::TwoPartFloat.new(2.0, -0.25).to_r
  end

  def test_normalize_keeps_the_high_part_on_the_integer_grid
    assert_equal Horologium::Numeric::TwoPartFloat.new(2.0, 0.3),
      Horologium::Numeric::TwoPartFloat.normalize(2.0, 0.3)
  end

  def test_normalize_carries_a_low_part_over_half_a_unit_up_into_the_high_part
    assert_equal Horologium::Numeric::TwoPartFloat.new(3.0, -0.25),
      Horologium::Numeric::TwoPartFloat.normalize(2.0, 0.75)
  end

  def test_normalize_carries_a_negative_low_part_down_into_the_high_part
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.0, 0.25),
      Horologium::Numeric::TwoPartFloat.normalize(2.0, -0.75)
  end

  def test_multiplication_multiplies_by_a_scalar
    assert_equal Horologium::Numeric::TwoPartFloat.new(3.0),
      Horologium::Numeric::TwoPartFloat.new(1.5) * 2
  end

  def test_multiplication_retains_precision_a_plain_float_would_lose
    value = Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16)

    assert_equal value.to_r * 2, (value * 2).to_r
  end

  def test_multiplication_by_a_scalar_matches_the_exact_product
    value = Horologium::Numeric::TwoPartFloat.new(2_460_000.5, 1e-9)

    assert_in_delta value.to_r * 86_400, (value * 86_400).to_r, 1e-6
  end

  def test_division_divides_by_a_scalar
    assert_equal Horologium::Numeric::TwoPartFloat.new(1.5),
      Horologium::Numeric::TwoPartFloat.new(3.0) / 2
  end

  def test_division_is_exact_when_the_value_divides_evenly
    assert_equal Horologium::Numeric::TwoPartFloat.new(3.5),
      Horologium::Numeric::TwoPartFloat.new(7.0) / 2
  end

  def test_division_retains_precision_a_plain_float_would_lose
    value = Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16)

    assert_equal value.to_r / 2, (value / 2).to_r
  end

  def test_division_by_a_scalar_matches_the_exact_quotient
    value = Horologium::Numeric::TwoPartFloat.new(2_460_000.5, 1e-9)

    assert_in_delta value.to_r / 86_400, (value / 86_400).to_r, 1e-9
  end

  def test_two_product_reconstructs_the_exact_product_of_its_operands
    product, error = Horologium::Numeric::TwoPartFloat.two_product(0.1, 0.2)

    assert_equal Rational(0.1) * Rational(0.2),
      Rational(product) + Rational(error)
  end

  def test_two_product_leaves_no_error_for_exactly_representable_operands
    assert_equal [6.0, 0.0],
      Horologium::Numeric::TwoPartFloat.two_product(2.0, 3.0)
  end

  def test_split_halves_add_back_to_the_original_value
    high, low = Horologium::Numeric::TwoPartFloat.split(0.1)

    assert_equal Rational(0.1), Rational(high) + Rational(low)
  end

  def test_split_returns_the_value_and_zero_for_a_small_integer
    assert_equal [3.0, 0.0], Horologium::Numeric::TwoPartFloat.split(3.0)
  end

  def test_from_real_keeps_precision_a_single_float_would_lose
    assert_equal 2**53 + 1,
      Horologium::Numeric::TwoPartFloat.from_real(2**53 + 1).to_r
  end

  def test_multiplication_keeps_double_precision_for_an_unnormalized_pair
    value = Horologium::Numeric::TwoPartFloat.new(0.1, -0.25)
    exact = value.to_r * 1_000_000_000

    assert_operator ((value * 1_000_000_000).to_r - exact).abs, :<,
      exact.abs / 10**20
  end

  def test_division_keeps_double_precision_for_an_unnormalized_pair
    value = Horologium::Numeric::TwoPartFloat.new(1e-9, 0.3)
    exact = value.to_r / 7

    assert_operator ((value / 7).to_r - exact).abs, :<, exact.abs / 10**20
  end

  def test_division_raises_when_dividing_by_zero
    assert_raises(ZeroDivisionError) do
      Horologium::Numeric::TwoPartFloat.new(3.0) / 0
    end
  end
end
