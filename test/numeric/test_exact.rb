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
end
