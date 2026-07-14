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
    assert_raises(ArgumentError) do
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
end
