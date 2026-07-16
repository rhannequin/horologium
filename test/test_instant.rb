# frozen_string_literal: true

require "test_helper"

class TestInstant < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_is_frozen
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)

    assert_predicate instant, :frozen?
  end

  def test_it_is_equal_to_another_instant_at_the_same_point
    assert_equal Horologium::Instant.from_tai_julian_date(2_460_000.5),
      Horologium::Instant.from_tai_julian_date(2_460_000.5)
  end

  def test_adding_a_duration_returns_a_later_instant
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)

    assert_equal Horologium::Instant.from_tai_julian_date(2_460_001.5),
      instant + Horologium::Duration.days(1)
  end

  def test_subtracting_a_duration_returns_an_earlier_instant
    instant = Horologium::Instant.from_tai_julian_date(2_460_001.5)

    assert_equal Horologium::Instant.from_tai_julian_date(2_460_000.5),
      instant - Horologium::Duration.days(1)
  end

  def test_subtracting_two_instants_returns_the_duration_between_them
    earlier = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    later = Horologium::Instant.from_tai_julian_date(2_460_001.5)

    assert_equal Horologium::Duration.days(1), later - earlier
  end

  def test_subtracting_two_exact_instants_returns_an_exact_duration
    earlier = Horologium::Instant.from_tai_julian_date(
      2_460_000.5,
      precision: :exact
    )
    later = Horologium::Instant.from_tai_julian_date(
      2_460_001.5,
      precision: :exact
    )
    gap = later - earlier

    assert_equal :exact, gap.precision
    assert_equal Horologium::Duration.days(1, precision: :exact), gap
  end

  def test_standard_instants_are_normalized_to_the_integer_day_grid
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.9)

    assert_equal Horologium::Numeric::TwoPartFloat.normalize(2_460_000.9),
      instant.value
  end

  def test_adding_then_subtracting_a_duration_returns_the_original_instant
    instant = Horologium::Instant.from_tai_julian_date(
      2_460_000.5, precision: :exact
    )
    duration = Horologium::Duration.seconds(3600, precision: :exact)

    assert_equal instant, (instant + duration) - duration
  end

  def test_adding_a_non_duration_raises_a_dimensional_error
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)

    assert_raises(Horologium::DimensionalError) do
      instant + instant
    end
  end

  def test_subtracting_an_unsupported_operand_raises_a_dimensional_error
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)

    assert_raises(Horologium::DimensionalError) do
      instant - 1
    end
  end

  def test_it_orders_instants_by_the_point_they_mark
    assert_operator Horologium::Instant.from_tai_julian_date(2_460_000.5), :<,
      Horologium::Instant.from_tai_julian_date(2_460_001.5)
  end

  def test_it_sorts_by_the_point_they_mark
    instants = [
      Horologium::Instant.from_tai_julian_date(2_460_002.5),
      Horologium::Instant.from_tai_julian_date(2_460_000.5),
      Horologium::Instant.from_tai_julian_date(2_460_001.5)
    ]

    assert_equal [
      Horologium::Instant.from_tai_julian_date(2_460_000.5),
      Horologium::Instant.from_tai_julian_date(2_460_001.5),
      Horologium::Instant.from_tai_julian_date(2_460_002.5)
    ], instants.sort
  end

  def test_it_is_equal_across_precisions_by_point
    standard = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    exact = Horologium::Instant.from_tai_julian_date(
      2_460_000.5,
      precision: :exact
    )

    assert_equal standard, exact
  end

  def test_it_is_not_eql_across_precisions
    standard = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    exact = Horologium::Instant.from_tai_julian_date(
      2_460_000.5,
      precision: :exact
    )

    refute_operator standard, :eql?, exact
  end

  def test_instants_of_different_precisions_are_distinct_hash_keys
    standard = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    exact = Horologium::Instant.from_tai_julian_date(
      2_460_000.5,
      precision: :exact
    )
    store = {standard => :standard, exact => :exact}

    assert_equal 2, store.size
  end

  def test_equal_within_is_true_inside_the_tolerance
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    nearby = instant + Horologium::Duration.nanoseconds(1)

    assert instant.equal_within?(nearby, Horologium::Duration.nanoseconds(2))
  end

  def test_equal_within_is_false_outside_the_tolerance
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    far = instant + Horologium::Duration.seconds(2)

    refute instant.equal_within?(far, Horologium::Duration.seconds(1))
  end

  def test_mixing_precisions_promotes_the_result_to_exact
    instant = Horologium::Instant.from_tai_julian_date(
      2_460_000.5,
      precision: :exact
    )
    duration = Horologium::Duration.seconds(1, precision: :standard)

    assert_equal :exact, (instant + duration).precision
  end

  def test_mixing_precisions_computes_the_correct_value
    instant = Horologium::Instant.from_tai_julian_date(
      2_460_000.5,
      precision: :exact
    )
    duration = Horologium::Duration.seconds(86_400, precision: :standard)

    assert_equal Horologium::Instant.from_tai_julian_date(
      2_460_001.5,
      precision: :exact
    ), instant + duration
  end

  def test_a_standard_instant_promotes_when_added_to_an_exact_duration
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    duration = Horologium::Duration.seconds(86_400, precision: :exact)
    sum = instant + duration

    assert_equal :exact, sum.precision
    assert_equal Horologium::Instant.from_tai_julian_date(
      2_460_001.5,
      precision: :exact
    ), sum
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::Instant.from_tai_julian_date(2_460_000.5),
      Object.new
  end

  def test_equal_within_rejects_a_non_instant
    instant = Horologium::Instant.from_tai_julian_date(2_460_000.5)

    assert_raises(Horologium::DimensionalError) do
      instant.equal_within?(
        Horologium::Duration.seconds(1),
        Horologium::Duration.seconds(2)
      )
    end
  end

  def test_new_rejects_an_unknown_precision
    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Instant.new(Horologium::Numeric::Exact.new(1), :fast)
    end
  end

  def test_new_rejects_a_value_that_does_not_match_the_precision
    assert_raises(ArgumentError) do
      Horologium::Instant.new(Horologium::Numeric::Exact.new(1), :standard)
    end
  end

  def test_equal_within_rejects_a_non_duration_tolerance
    a = Horologium::Instant.from_tai_julian_date(2_460_000.5)
    b = Horologium::Instant.from_tai_julian_date(2_460_000.5)

    assert_raises(Horologium::DimensionalError) do
      a.equal_within?(b, 5)
    end
  end

  def test_it_takes_the_precision_in_effect_by_default
    precision = Horologium.with_precision(:exact) do
      Horologium::Instant.from_tai_julian_date(2_460_000.5).precision
    end

    assert_equal :exact, precision
  end

  def test_the_exact_precision_keeps_the_two_part_input_losslessly
    instant = Horologium::Instant.from_tai_julian_date(
      2_460_000.5, 1e-16, precision: :exact
    )

    assert_equal Rational(2_460_000.5) + Rational(1e-16), instant.value.to_r
  end

  def test_it_reads_in_a_scale
    instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)

    assert_instance_of Horologium::ScaleReading, instant.to(:tt)
  end

  def test_reading_in_tt_moves_the_julian_date_32_point_184_seconds_ahead
    instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)

    assert_in_delta 2_443_144.500_372_5,
      instant.to(:tt).as(:julian_date),
      1e-9
  end

  def test_reading_in_an_unregistered_scale_raises_an_unknown_scale_error
    instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)

    assert_raises(Horologium::UnknownScaleError) do
      instant.to(:sundial)
    end
  end

  def test_as_is_the_shorthand_for_reading_in_a_scale_then_representing_it
    instant = Horologium::Instant.from_tai_julian_date(2_443_144.5)

    assert_in_delta instant.to(:tt).as(:julian_date),
      instant.as(:julian_date, scale: :tt),
      1e-9
  end

  def test_as_passes_the_output_type_on_to_the_representation
    instant = Horologium::Instant.from_tai_julian_date(
      2_443_144.5,
      precision: :exact
    )

    assert_equal Rational(24_431_445_003_725, 10_000_000),
      instant.as(:julian_date, scale: :tt, as: :rational)
  end
end
