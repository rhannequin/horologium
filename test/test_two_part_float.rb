# frozen_string_literal: true

require "test_helper"

class TestTwoPartFloat < Minitest::Test
  def test_it_is_frozen
    two_part_float = Horologium::TwoPartFloat.new(1.0, 0.5)

    assert_predicate two_part_float, :frozen?
  end

  def test_the_low_part_defaults_to_zero
    assert_equal Horologium::TwoPartFloat.new(1.0, 0.0),
      Horologium::TwoPartFloat.new(1.0)
  end

  def test_it_is_equal_to_another_instance_with_the_same_parts
    assert_equal Horologium::TwoPartFloat.new(1.0, 0.5),
      Horologium::TwoPartFloat.new(1.0, 0.5)
  end

  def test_it_is_not_equal_to_an_instance_with_a_different_part
    refute_equal Horologium::TwoPartFloat.new(1.0, 0.5),
      Horologium::TwoPartFloat.new(1.0, 0.25)
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::TwoPartFloat.new(1.0, 0.5), Object.new
  end

  def test_it_is_eql_to_an_instance_with_the_same_parts
    assert_operator Horologium::TwoPartFloat.new(1.0, 0.5), :eql?,
      Horologium::TwoPartFloat.new(1.0, 0.5)
  end

  def test_it_is_not_eql_to_an_instance_with_a_different_part
    refute_operator Horologium::TwoPartFloat.new(1.0, 0.5), :eql?,
      Horologium::TwoPartFloat.new(1.0, 0.25)
  end

  def test_equal_instances_share_the_same_hash
    assert_equal Horologium::TwoPartFloat.new(1.0, 0.5).hash,
      Horologium::TwoPartFloat.new(1.0, 0.5).hash
  end

  def test_it_can_be_used_as_a_hash_key
    store = {Horologium::TwoPartFloat.new(1.0, 0.5) => :value}

    assert_equal :value, store[Horologium::TwoPartFloat.new(1.0, 0.5)]
  end

  def test_two_sum_reconstructs_the_exact_sum_of_its_operands
    sum, error = Horologium::TwoPartFloat.two_sum(0.1, 0.2)

    assert_equal Rational(0.1) + Rational(0.2), Rational(sum) + Rational(error)
  end

  def test_two_sum_leaves_no_error_for_exactly_representable_operands
    assert_equal [3.0, 0.0], Horologium::TwoPartFloat.two_sum(1.0, 2.0)
  end

  def test_two_diff_reconstructs_the_exact_difference_of_its_operands
    difference, error = Horologium::TwoPartFloat.two_diff(1.0, 1e-16)

    assert_equal Rational(1.0) - Rational(1e-16),
      Rational(difference) + Rational(error)
  end

  def test_two_diff_captures_the_error_a_plain_subtraction_would_lose
    assert_equal [1e16, -1.0], Horologium::TwoPartFloat.two_diff(1e16, 1.0)
  end

  def test_fast_two_sum_reconstructs_the_exact_sum_when_the_first_operand_dominates
    assert_equal [1.0, 1e-16], Horologium::TwoPartFloat.fast_two_sum(1.0, 1e-16)
  end

  def test_addition_adds_two_ordinary_values
    assert_equal Horologium::TwoPartFloat.new(3.75),
      Horologium::TwoPartFloat.new(1.5) + Horologium::TwoPartFloat.new(2.25)
  end

  def test_addition_retains_precision_a_plain_float_would_lose
    assert_equal Horologium::TwoPartFloat.new(1.0, 1e-16),
      Horologium::TwoPartFloat.new(1.0) + Horologium::TwoPartFloat.new(1e-16)
  end

  def test_subtraction_subtracts_two_ordinary_values
    assert_equal Horologium::TwoPartFloat.new(1.25),
      Horologium::TwoPartFloat.new(1.5) - Horologium::TwoPartFloat.new(0.25)
  end

  def test_subtraction_retains_precision_a_plain_float_would_lose
    assert_equal Horologium::TwoPartFloat.new(1e-16), (
      Horologium::TwoPartFloat.new(1.0, 1e-16) -
        Horologium::TwoPartFloat.new(1.0)
    )
  end

  def test_normalize_keeps_the_high_part_on_the_integer_grid
    assert_equal Horologium::TwoPartFloat.new(2.0, 0.3),
      Horologium::TwoPartFloat.normalize(2.0, 0.3)
  end

  def test_normalize_carries_a_low_part_over_half_a_unit_up_into_the_high_part
    assert_equal Horologium::TwoPartFloat.new(3.0, -0.25),
      Horologium::TwoPartFloat.normalize(2.0, 0.75)
  end

  def test_normalize_carries_a_negative_low_part_down_into_the_high_part
    assert_equal Horologium::TwoPartFloat.new(1.0, 0.25),
      Horologium::TwoPartFloat.normalize(2.0, -0.75)
  end
end
