# frozen_string_literal: true

require "test_helper"

class TestPrecision < Minitest::Test
  def test_validate_returns_a_recognised_precision
    assert_equal :exact, Horologium::Numeric::Precision.validate!(:exact)
    assert_equal :standard, Horologium::Numeric::Precision.validate!(:standard)
  end

  def test_validate_rejects_an_unrecognised_precision
    error = assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Numeric::Precision.validate!(:fast)
    end

    assert_equal %i[standard exact], error.known_precisions
  end

  def test_resolve_keeps_two_standard_operands_standard
    assert_equal :standard,
      Horologium::Numeric::Precision.resolve(:standard, :standard)
  end

  def test_resolve_keeps_two_exact_operands_exact
    assert_equal :exact,
      Horologium::Numeric::Precision.resolve(:exact, :exact)
  end

  def test_resolve_promotes_a_mix_to_exact
    assert_equal :exact,
      Horologium::Numeric::Precision.resolve(:standard, :exact)
    assert_equal :exact,
      Horologium::Numeric::Precision.resolve(:exact, :standard)
  end

  def test_resolve_rejects_an_unrecognised_operand
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Numeric::Precision.resolve(:standard, :fast)
    end
  end

  def test_coerce_promotes_a_standard_value_to_exact
    two_part_float = Horologium::Numeric::TwoPartFloat.new(1.5, 0.25)

    assert_equal Horologium::Numeric::Exact.new(Rational(7, 4)),
      Horologium::Numeric::Precision.coerce(two_part_float, to: :exact)
  end

  def test_coerce_to_exact_loses_no_precision
    two_part_float = Horologium::Numeric::TwoPartFloat.new(1.0, 1e-16)

    assert_equal Horologium::Numeric::Exact.new(two_part_float.to_r),
      Horologium::Numeric::Precision.coerce(two_part_float, to: :exact)
  end

  def test_coerce_leaves_an_exact_value_in_exact_unchanged
    exact = Horologium::Numeric::Exact.new(Rational(1, 3))

    assert_same exact, Horologium::Numeric::Precision.coerce(exact, to: :exact)
  end

  def test_coerce_leaves_a_standard_value_in_standard_unchanged
    two_part_float = Horologium::Numeric::TwoPartFloat.new(1.0, 0.5)

    assert_same two_part_float,
      Horologium::Numeric::Precision.coerce(two_part_float, to: :standard)
  end

  def test_coerce_refuses_to_drop_an_exact_value_to_standard
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Precision.coerce(
        Horologium::Numeric::Exact.new(1),
        to: :standard
      )
    end
  end

  def test_coerce_rejects_an_unrecognised_target
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Numeric::Precision.coerce(
        Horologium::Numeric::TwoPartFloat.new(1.0),
        to: :fast
      )
    end
  end

  def test_build_holds_a_standard_value_as_a_two_part_float
    value = Horologium::Numeric::Precision.build(Rational(1, 3), :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, value
  end

  def test_build_holds_an_exact_value_as_a_rational
    value = Horologium::Numeric::Precision.build(Rational(1, 3), :exact)

    assert_equal Rational(1, 3), value.to_r
  end

  def test_build_rejects_an_unrecognised_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Numeric::Precision.build(1, :fast)
    end
  end

  def test_build_each_holds_the_value_at_every_precision
    table = Horologium::Numeric::Precision.build_each(Rational(1, 3))

    assert_equal Horologium::Numeric::Precision::NAMES, table.keys
    assert_instance_of Horologium::Numeric::TwoPartFloat, table[:standard]
    assert_equal Rational(1, 3), table[:exact].to_r
  end

  def test_build_each_is_frozen
    table = Horologium::Numeric::Precision.build_each(1)

    assert_predicate table, :frozen?
  end

  def test_build_each_rejects_an_unrecognised_precision_when_it_is_read
    table = Horologium::Numeric::Precision.build_each(1)

    assert_raises(Horologium::UnknownPrecisionError) { table[:fast] }
  end

  def test_two_standard_values_add_in_the_split
    sum = Horologium::Numeric::Precision.add(
      Horologium::Numeric::TwoPartFloat.new(1.0),
      Horologium::Numeric::TwoPartFloat.new(0.5)
    )

    assert_instance_of Horologium::Numeric::TwoPartFloat, sum
    assert_equal Rational(3, 2), sum.to_r
  end

  def test_adding_an_exact_value_to_a_standard_one_promotes_the_sum
    sum = Horologium::Numeric::Precision.add(
      Horologium::Numeric::TwoPartFloat.new(1.0),
      Horologium::Numeric::Exact.new(Rational(1, 3))
    )

    assert_instance_of Horologium::Numeric::Exact, sum
    assert_equal Rational(4, 3), sum.to_r
  end

  def test_two_standard_values_subtract_in_the_split
    difference = Horologium::Numeric::Precision.subtract(
      Horologium::Numeric::TwoPartFloat.new(1.5),
      Horologium::Numeric::TwoPartFloat.new(0.5)
    )

    assert_instance_of Horologium::Numeric::TwoPartFloat, difference
    assert_equal 1, difference.to_r
  end

  def test_subtracting_an_exact_value_from_a_standard_one_promotes_the_result
    difference = Horologium::Numeric::Precision.subtract(
      Horologium::Numeric::TwoPartFloat.new(1.0),
      Horologium::Numeric::Exact.new(Rational(1, 3))
    )

    assert_instance_of Horologium::Numeric::Exact, difference
    assert_equal Rational(2, 3), difference.to_r
  end

  def test_adding_a_plain_number_is_refused_rather_than_promoted
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Precision.add(
        Horologium::Numeric::TwoPartFloat.new(1.0),
        Rational(1, 3)
      )
    end
  end

  def test_subtracting_a_plain_number_is_refused_rather_than_promoted
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Precision.subtract(
        Horologium::Numeric::TwoPartFloat.new(1.0),
        0.5
      )
    end
  end

  def test_validate_value_accepts_a_value_that_matches_its_precision
    value = Horologium::Numeric::TwoPartFloat.new(1.0)

    assert_same value,
      Horologium::Numeric::Precision.validate_value!(value, :standard)
  end

  def test_validate_value_rejects_a_value_that_does_not_match_its_precision
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Numeric::Precision.validate_value!(
        Horologium::Numeric::Exact.new(1),
        :standard
      )
    end
  end

  def test_compare_orders_two_standard_values
    assert_equal(-1, Horologium::Numeric::Precision.compare(
      Horologium::Numeric::TwoPartFloat.new(1.0),
      Horologium::Numeric::TwoPartFloat.new(2.0)
    ))
  end

  def test_compare_reads_the_number_and_not_the_parts_it_is_spelled_with
    assert_equal 0, Horologium::Numeric::Precision.compare(
      Horologium::Numeric::TwoPartFloat.new(2_460_796.0, 0.5),
      Horologium::Numeric::TwoPartFloat.new(2_460_797.0, -0.5)
    )
  end

  def test_compare_settles_a_close_pair_exactly
    assert_equal(-1, Horologium::Numeric::Precision.compare(
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.0),
      Horologium::Numeric::TwoPartFloat.new(1.0, 1e-300)
    ))
  end

  def test_compare_settles_parts_that_overflow_when_they_cancel
    assert_equal 0, Horologium::Numeric::Precision.compare(
      Horologium::Numeric::TwoPartFloat.new(1e308, -1e308),
      Horologium::Numeric::TwoPartFloat.new(-1e308, 1e308)
    )
  end

  def test_compare_orders_across_precisions
    assert_equal 0, Horologium::Numeric::Precision.compare(
      Horologium::Numeric::TwoPartFloat.new(1.0, 0.5),
      Horologium::Numeric::Exact.new(Rational(3, 2))
    )
  end
end
