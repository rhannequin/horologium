# frozen_string_literal: true

require "test_helper"

class TestExact < Minitest::Test
  def test_it_is_frozen
    exact_rational = Horologium::Numeric::Exact.new(1)

    assert_predicate exact_rational, :frozen?
  end

  def test_it_is_equal_to_another_instance_with_the_same_value
    assert_equal Horologium::Numeric::Exact.new(1),
      Horologium::Numeric::Exact.new(1)
  end

  def test_it_is_not_equal_to_an_instance_with_a_different_value
    refute_equal Horologium::Numeric::Exact.new(1),
      Horologium::Numeric::Exact.new(2)
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::Numeric::Exact.new(1), Object.new
  end

  def test_it_stores_a_float_as_its_exact_binary_value
    assert_equal Horologium::Numeric::Exact.new(Rational(1, 2)),
      Horologium::Numeric::Exact.new(0.5)
  end

  def test_it_stores_a_rational_without_rounding
    exact_rational = Horologium::Numeric::Exact.new(Rational(1, 3))

    assert_equal exact_rational, Horologium::Numeric::Exact.new(Rational(1, 3))
    assert_operator exact_rational, :eql?,
      Horologium::Numeric::Exact.new(Rational(1, 3))
    assert_equal exact_rational.hash,
      Horologium::Numeric::Exact.new(Rational(1, 3)).hash
  end

  def test_it_is_eql_to_an_instance_with_the_same_value
    assert_operator Horologium::Numeric::Exact.new(1), :eql?,
      Horologium::Numeric::Exact.new(1)
  end

  def test_it_is_not_eql_to_an_instance_with_a_different_value
    refute_operator Horologium::Numeric::Exact.new(1), :eql?,
      Horologium::Numeric::Exact.new(2)
  end

  def test_equal_instances_share_the_same_hash
    assert_equal Horologium::Numeric::Exact.new(1).hash,
      Horologium::Numeric::Exact.new(1).hash
  end

  def test_it_can_be_used_as_a_hash_key
    store = {Horologium::Numeric::Exact.new(1) => :value}

    assert_equal :value, store[Horologium::Numeric::Exact.new(1)]
  end

  def test_it_returns_its_value_as_a_rational
    assert_equal Rational(1, 3),
      Horologium::Numeric::Exact.new(Rational(1, 3)).to_r
  end

  def test_addition_adds_two_exact_values
    assert_equal Horologium::Numeric::Exact.new(Rational(1, 2)),
      Horologium::Numeric::Exact.new(Rational(1, 3)) +
        Horologium::Numeric::Exact.new(Rational(1, 6))
  end

  def test_subtraction_subtracts_two_exact_values
    assert_equal Horologium::Numeric::Exact.new(Rational(1, 3)),
      Horologium::Numeric::Exact.new(Rational(1, 2)) -
        Horologium::Numeric::Exact.new(Rational(1, 6))
  end

  def test_multiplication_multiplies_by_an_integer_scalar
    assert_equal Horologium::Numeric::Exact.new(2),
      Horologium::Numeric::Exact.new(Rational(1, 3)) * 6
  end

  def test_multiplication_by_a_negative_scalar
    assert_equal Horologium::Numeric::Exact.new(-2),
      Horologium::Numeric::Exact.new(Rational(1, 3)) * -6
  end

  def test_multiplication_by_a_rational_scalar_stays_exact
    assert_equal Horologium::Numeric::Exact.new(Rational(1, 6)),
      Horologium::Numeric::Exact.new(Rational(1, 2)) * Rational(1, 3)
  end

  def test_division_divides_by_a_scalar
    assert_equal Horologium::Numeric::Exact.new(Rational(1, 3)),
      Horologium::Numeric::Exact.new(2) / 6
  end

  def test_arithmetic_matches_raw_rational_arithmetic
    left = Rational(2, 7)
    right = Rational(3, 11)

    assert_equal Horologium::Numeric::Exact.new(left + right),
      Horologium::Numeric::Exact.new(left) +
        Horologium::Numeric::Exact.new(right)
    assert_equal Horologium::Numeric::Exact.new(left / 4),
      Horologium::Numeric::Exact.new(left) / 4
  end

  def test_it_collapses_into_the_nearest_float
    value = Horologium::Numeric::Exact.new(
      Rational(24_431_445_003_725, 10_000_000)
    )

    assert_in_delta 2_443_144.500_372_5, value.to_f, 1e-9
  end

  def test_multiplication_rejects_an_exact_value
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Exact.new(3) * Horologium::Numeric::Exact.new(2)
    end
  end

  def test_division_rejects_an_exact_value
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Exact.new(3) / Horologium::Numeric::Exact.new(2)
    end
  end

  def test_it_is_zero_when_it_holds_nothing
    assert_predicate Horologium::Numeric::Exact.new(0), :zero?
  end

  def test_it_reads_its_sign_from_the_value_it_holds
    assert_predicate Horologium::Numeric::Exact.new(Rational(1, 3)), :positive?
    assert_predicate Horologium::Numeric::Exact.new(Rational(-1, 3)), :negative?
  end

  def test_it_refuses_a_value_with_no_rational_form
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Exact.new(Float::NAN)
    end
  end

  def test_it_refuses_something_that_is_not_a_number
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Exact.new(:soon)
    end
  end
end
