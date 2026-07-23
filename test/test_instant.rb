# frozen_string_literal: true

require "test_helper"

class TestInstant < Minitest::Test
  def teardown
    Horologium.reset_configuration!
  end

  def test_it_is_frozen
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

    assert_predicate instant, :frozen?
  end

  def test_it_is_equal_to_another_instant_at_the_same_point
    assert_equal Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai),
      Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
  end

  def test_adding_a_duration_returns_a_later_instant
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

    assert_equal Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai),
      instant + Horologium::Duration.days(1)
  end

  def test_subtracting_a_duration_returns_an_earlier_instant
    instant = Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)

    assert_equal Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai),
      instant - Horologium::Duration.days(1)
  end

  def test_subtracting_two_instants_returns_the_duration_between_them
    earlier = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    later = Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)

    assert_equal Horologium::Duration.days(1), later - earlier
  end

  def test_subtracting_two_exact_instants_returns_an_exact_duration
    earlier = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )
    later = Horologium::Instant.from_julian_date(
      2_460_001.5,
      scale: :tai,
      precision: :exact
    )
    gap = later - earlier

    assert_equal :exact, gap.precision
    assert_equal Horologium::Duration.days(1, precision: :exact), gap
  end

  def test_standard_instants_are_normalized_to_the_integer_day_grid
    instant = Horologium::Instant.from_julian_date(2_460_000.9, scale: :tai)

    assert_equal Horologium::Numeric::TwoPartFloat.normalize(2_460_000.9),
      instant.value
  end

  def test_adding_then_subtracting_a_duration_returns_the_original_instant
    instant = Horologium::Instant.from_julian_date(
      2_460_000.5, scale: :tai, precision: :exact
    )
    duration = Horologium::Duration.seconds(3600, precision: :exact)

    assert_equal instant, (instant + duration) - duration
  end

  def test_adding_a_non_duration_raises_a_dimensional_error
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

    assert_raises(Horologium::DimensionalError) do
      instant + instant
    end
  end

  def test_subtracting_an_unsupported_operand_raises_a_dimensional_error
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

    assert_raises(Horologium::DimensionalError) do
      instant - 1
    end
  end

  def test_it_orders_instants_by_the_point_they_mark
    assert_operator Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai
    ), :<, Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)
  end

  def test_it_sorts_by_the_point_they_mark
    instants = [
      Horologium::Instant.from_julian_date(2_460_002.5, scale: :tai),
      Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai),
      Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai)
    ]

    assert_equal [
      Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai),
      Horologium::Instant.from_julian_date(2_460_001.5, scale: :tai),
      Horologium::Instant.from_julian_date(2_460_002.5, scale: :tai)
    ], instants.sort
  end

  def test_it_is_equal_across_precisions_by_point
    standard = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    exact = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )

    assert_equal standard, exact
  end

  def test_it_is_not_eql_across_precisions
    standard = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    exact = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )

    refute_operator standard, :eql?, exact
  end

  def test_instants_of_different_precisions_are_distinct_hash_keys
    standard = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    exact = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )
    store = {standard => :standard, exact => :exact}

    assert_equal 2, store.size
  end

  def test_equal_within_is_true_inside_the_tolerance
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    nearby = instant + Horologium::Duration.nanoseconds(1)

    assert instant.equal_within?(nearby, Horologium::Duration.nanoseconds(2))
  end

  def test_equal_within_is_false_outside_the_tolerance
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    far = instant + Horologium::Duration.seconds(2)

    refute instant.equal_within?(far, Horologium::Duration.seconds(1))
  end

  def test_mixing_precisions_promotes_the_result_to_exact
    instant = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )
    duration = Horologium::Duration.seconds(1, precision: :standard)

    assert_equal :exact, (instant + duration).precision
  end

  def test_mixing_precisions_computes_the_correct_value
    instant = Horologium::Instant.from_julian_date(
      2_460_000.5,
      scale: :tai,
      precision: :exact
    )
    duration = Horologium::Duration.seconds(86_400, precision: :standard)

    assert_equal Horologium::Instant.from_julian_date(
      2_460_001.5,
      scale: :tai,
      precision: :exact
    ), instant + duration
  end

  def test_a_standard_instant_promotes_when_added_to_an_exact_duration
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    duration = Horologium::Duration.seconds(86_400, precision: :exact)
    sum = instant + duration

    assert_equal :exact, sum.precision
    assert_equal Horologium::Instant.from_julian_date(
      2_460_001.5,
      scale: :tai,
      precision: :exact
    ), sum
  end

  def test_it_is_not_equal_to_a_value_of_another_type
    refute_equal Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai),
      Object.new
  end

  def test_equal_within_rejects_a_non_instant
    instant = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

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
    a = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)
    b = Horologium::Instant.from_julian_date(2_460_000.5, scale: :tai)

    assert_raises(Horologium::DimensionalError) do
      a.equal_within?(b, 5)
    end
  end

  def test_it_takes_the_precision_in_effect_by_default
    precision = Horologium.with_precision(:exact) do
      Horologium::Instant
        .from_julian_date(2_460_000.5, scale: :tai)
        .precision
    end

    assert_equal :exact, precision
  end

  def test_the_exact_precision_keeps_the_two_part_input_losslessly
    instant = Horologium::Instant.from_julian_date(
      2_460_000.5, 1e-16, scale: :tai, precision: :exact
    )

    assert_equal Rational(2_460_000.5) + Rational(1e-16), instant.value.to_r
  end

  def test_a_julian_date_given_in_tt_is_stored_in_tai
    instant = Horologium::Instant.from_julian_date(
      "2443144.5003725",
      scale: :tt,
      precision: :exact
    )

    assert_equal Rational(24_431_445, 10), instant.value.to_r
  end

  def test_a_julian_date_given_in_tt_reads_back_in_tt
    instant = Horologium::Instant.from_julian_date(
      "2443144.5003725",
      scale: :tt,
      precision: :exact
    )

    assert_equal Rational(24_431_445_003_725, 10_000_000),
      instant.as(:julian_date, scale: :tt, as: :rational)
  end

  def test_a_julian_date_given_as_a_string_keeps_every_digit
    instant = Horologium::Instant.from_julian_date(
      "2456463.052272",
      scale: :tai,
      precision: :exact
    )

    assert_equal Rational(2_456_463_052_272, 1_000_000), instant.value.to_r
  end

  def test_a_julian_date_given_as_a_rational_keeps_every_digit
    instant = Horologium::Instant.from_julian_date(
      Rational(2_456_463_052_272, 1_000_000),
      scale: :tai,
      precision: :exact
    )

    assert_equal Rational(2_456_463_052_272, 1_000_000), instant.value.to_r
  end

  def test_a_julian_date_given_as_an_integer_marks_the_start_of_that_day
    instant = Horologium::Instant.from_julian_date(2_456_463, scale: :tai)

    assert_in_delta 2_456_463.0,
      instant.as(:julian_date, scale: :tai),
      1e-9
  end

  def test_a_julian_date_given_as_two_parts_keeps_what_one_float_would_lose
    instant = Horologium::Instant.from_julian_date(
      2_456_463.0,
      0.052272,
      scale: :tai,
      precision: :exact
    )

    assert_equal Rational(2_456_463.0) + Rational(0.052272),
      instant.value.to_r
  end

  def test_a_julian_date_given_as_a_string_is_read_strictly
    error = assert_raises(Horologium::ParseError) do
      Horologium::Instant.from_julian_date("2456463.05e2", scale: :tai)
    end

    assert_includes error.message, "2456463.05e2"
  end

  def test_a_julian_date_of_an_unreadable_type_is_refused
    assert_raises(ArgumentError) do
      Horologium::Instant.from_julian_date(nil, scale: :tai)
    end
  end

  def test_the_low_part_of_a_julian_date_is_a_float
    assert_raises(ArgumentError) do
      Horologium::Instant.from_julian_date(
        2_456_463.0,
        Rational(52_272, 1_000_000),
        scale: :tai
      )
    end
  end

  def test_building_in_an_unregistered_scale_raises_an_unknown_scale_error
    assert_raises(Horologium::UnknownScaleError) do
      Horologium::Instant.from_julian_date(2_443_144.5, scale: :sundial)
    end
  end

  def test_it_takes_the_precision_in_effect_when_built_from_a_julian_date
    precision = Horologium.with_precision(:exact) do
      Horologium::Instant
        .from_julian_date("2456463.052272", scale: :tt)
        .precision
    end

    assert_equal :exact, precision
  end

  def test_a_modified_julian_date_is_the_julian_date_from_a_later_origin
    instant = Horologium::Instant.from_modified_julian_date(
      60_796.0,
      scale: :tai
    )

    assert_in_delta 2_460_796.5,
      instant.as(:julian_date, scale: :tai),
      1e-9
  end

  def test_a_modified_julian_date_reads_back_as_the_one_it_was_given
    instant = Horologium::Instant.from_modified_julian_date(
      "60796.052272",
      scale: :tt,
      precision: :exact
    )

    assert_equal Rational(60_796_052_272, 1_000_000),
      instant.as(:modified_julian_date, scale: :tt, as: :rational)
  end

  def test_a_modified_julian_date_given_in_an_unregistered_scale_is_refused
    assert_raises(Horologium::UnknownScaleError) do
      Horologium::Instant.from_modified_julian_date(60_796.0, scale: :sundial)
    end
  end

  def test_it_reads_in_a_scale
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_instance_of Horologium::ScaleReading, instant.to(:tt)
  end

  def test_reading_in_tt_moves_the_julian_date_32_point_184_seconds_ahead
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_in_delta 2_443_144.500_372_5,
      instant.to(:tt).as(:julian_date),
      1e-9
  end

  def test_reading_in_an_unregistered_scale_raises_an_unknown_scale_error
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_raises(Horologium::UnknownScaleError) do
      instant.to(:sundial)
    end
  end

  def test_as_is_the_shorthand_for_reading_in_a_scale_then_representing_it
    instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)

    assert_in_delta instant.to(:tt).as(:julian_date),
      instant.as(:julian_date, scale: :tt),
      1e-9
  end

  def test_as_passes_the_output_type_on_to_the_representation
    instant = Horologium::Instant.from_julian_date(
      2_443_144.5,
      scale: :tai,
      precision: :exact
    )

    assert_equal Rational(24_431_445_003_725, 10_000_000),
      instant.as(:julian_date, scale: :tt, as: :rational)
  end

  def test_a_civil_date_marks_the_point_that_calendar_date_names
    assert_equal Horologium::Instant.from_julian_date(
      2_443_144.5,
      scale: :tai
    ),
      Horologium::Instant.from_civil(1977, 1, 1, scale: :tai)
  end

  def test_a_civil_date_given_in_tt_is_stored_in_tai
    instant = Horologium::Instant.from_civil(1977, 1, 1, scale: :tt)

    assert_in_delta 2_443_144.499_627_5,
      instant.as(:julian_date, scale: :tai),
      1e-9
  end

  def test_a_civil_date_reads_back_as_the_fields_it_was_given
    civil = Horologium::Instant
      .from_civil(2025, 5, 1, 12, 34, 56, scale: :tt)
      .as(:civil, scale: :tt)

    assert_equal 2025, civil.year
    assert_equal 5, civil.month
    assert_equal 1, civil.day
    assert_equal 12, civil.hour
    assert_equal 34, civil.minute
    assert_equal 56, civil.second
  end

  def test_the_time_of_day_of_a_civil_date_defaults_to_midnight
    assert_equal Horologium::Instant.from_civil(2025, 5, 1, 0, 0, 0,
      scale: :tai),
      Horologium::Instant.from_civil(2025, 5, 1, scale: :tai)
  end

  def test_a_civil_date_takes_a_fraction_of_a_second_exactly
    Horologium.with_precision(:exact) do
      assert_equal Horologium::Instant.from_civil(2025, 5, 1, scale: :tai) +
        Horologium::Duration.nanoseconds(250_000_000),
        Horologium::Instant.from_civil(
          2025, 5, 1, 0, 0, Rational(1, 4),
          scale: :tai
        )
    end
  end

  def test_a_civil_time_reads_back_into_the_instant_it_came_from
    instant = Horologium::Instant.from_civil(
      2025, 5, 1, 12, 34, Rational(111, 2),
      scale: :tt,
      precision: :exact
    )
    civil = instant.as(:civil, scale: :tt, as: :rational)

    assert_equal instant,
      Horologium::Instant.from_civil(civil, scale: :tt, precision: :exact)
  end

  def test_the_same_civil_date_in_two_scales_marks_two_points
    refute_equal Horologium::Instant.from_civil(2025, 5, 1, scale: :tai),
      Horologium::Instant.from_civil(2025, 5, 1, scale: :tt)
  end

  def test_building_from_a_civil_date_in_an_unregistered_scale_is_refused
    assert_raises(Horologium::UnknownScaleError) do
      Horologium::Instant.from_civil(2025, 5, 1, scale: :sundial)
    end
  end

  def test_it_takes_the_precision_in_effect_when_built_from_a_civil_date
    instant = Horologium.with_precision(:exact) do
      Horologium::Instant.from_civil(2025, 5, 1, scale: :tai)
    end

    assert_equal :exact, instant.precision
  end
end
