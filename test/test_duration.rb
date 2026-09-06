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

  def test_minutes_are_sixty_seconds_each
    assert_equal Horologium::Duration.seconds(5400),
      Horologium::Duration.minutes(90)
  end

  def test_hours_are_sixty_minutes_each
    assert_equal Horologium::Duration.minutes(360),
      Horologium::Duration.hours(6)
  end

  def test_a_julian_year_is_365_25_days
    assert_equal Horologium::Duration.days(365.25),
      Horologium::Duration.julian_years(1)
  end

  def test_a_julian_century_is_a_hundred_julian_years
    assert_equal Horologium::Duration.julian_years(100),
      Horologium::Duration.julian_centuries(1)
  end

  def test_julian_centuries_take_a_fraction_of_one
    assert_equal Horologium::Duration.days(9131.25),
      Horologium::Duration.julian_centuries(0.25)
  end

  def test_the_zero_constructor_holds_no_time_at_all
    assert_predicate Horologium::Duration.zero, :zero?
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
    assert_raises(Horologium::InvalidValueError) do
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

  # Reading a duration in a unit.

  def test_it_reads_itself_in_seconds
    assert_in_delta 86_400.0, Horologium::Duration.days(1).in_seconds
  end

  def test_it_reads_itself_in_minutes
    assert_in_delta 60.0, Horologium::Duration.hours(1).in_minutes
  end

  def test_it_reads_itself_in_hours
    assert_in_delta 24.0, Horologium::Duration.days(1).in_hours
  end

  def test_it_reads_itself_in_days
    assert_in_delta 0.5, Horologium::Duration.hours(12).in_days
  end

  def test_it_reads_itself_in_julian_years
    assert_in_delta 1.0, Horologium::Duration.days(365.25).in_julian_years
  end

  def test_it_reads_itself_in_julian_centuries
    assert_in_delta 1.0, Horologium::Duration.days(36_525).in_julian_centuries
  end

  def test_an_exact_duration_reads_a_unit_as_a_rational
    duration = Horologium::Duration.julian_years(1, precision: :exact)

    assert_equal Rational(1461, 4), duration.in_days
  end

  def test_a_standard_duration_reads_a_unit_as_a_float
    assert_instance_of Float, Horologium::Duration.days(1).in_days
  end

  def test_reading_a_unit_divides_before_it_becomes_a_float
    duration = Horologium::Duration.seconds(2**53 + 1)

    assert_equal Rational(2**53 + 1, 86_400).to_f, duration.in_days
  end

  def test_inspect_shows_the_seconds_and_the_precision
    duration = Horologium::Duration.seconds(3600)

    assert_equal "#<Horologium::Duration 3600.0 s (standard)>",
      duration.inspect
  end

  def test_a_duration_scales_by_a_number
    assert_equal Horologium::Duration.minutes(90),
      Horologium::Duration.hours(1) * 1.5
  end

  def test_a_duration_divides_by_a_number
    assert_equal Horologium::Duration.minutes(30),
      Horologium::Duration.hours(1) / 2
  end

  def test_scaling_stays_exact_at_the_exact_precision
    duration = Horologium::Duration.seconds(1, precision: :exact)

    assert_equal Rational(1, 3), (duration / 3).to_r
  end

  def test_dividing_by_zero_raises_the_error_ruby_raises
    assert_raises(ZeroDivisionError) do
      Horologium::Duration.seconds(1) / 0
    end
  end

  def test_scaling_refuses_something_that_is_not_a_number
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Duration.seconds(1) * :twice
    end
  end

  def test_the_mean_of_some_durations
    assert_equal Horologium::Duration.seconds(2),
      Horologium::Duration.mean(
        [Horologium::Duration.seconds(1), Horologium::Duration.seconds(3)]
      )
  end

  def test_the_mean_is_exact_when_any_of_them_is
    mean = Horologium::Duration.mean(
      [
        Horologium::Duration.seconds(1, precision: :exact),
        Horologium::Duration.seconds(2)
      ]
    )

    assert_equal :exact, mean.precision
  end

  def test_the_mean_of_no_durations_is_refused
    assert_raises(Horologium::DimensionalError) do
      Horologium::Duration.mean([])
    end
  end

  def test_the_mean_of_things_that_are_not_durations_is_refused
    assert_raises(Horologium::DimensionalError) do
      Horologium::Duration.mean([1, 2])
    end
  end

  def test_it_reads_an_iso_8601_duration
    assert_equal 14_706,
      Horologium::Duration.parse("PT4H5M6S", precision: :exact).in_seconds
  end

  def test_it_reads_a_duration_of_whole_days
    assert_equal 259_200,
      Horologium::Duration.parse("P3D", precision: :exact).in_seconds
  end

  def test_it_reads_a_negative_duration
    assert_equal(-3600,
      Horologium::Duration.parse("-PT1H", precision: :exact).in_seconds)
  end

  def test_it_reads_a_fraction_on_the_smallest_field
    assert_equal Rational(1, 2),
      Horologium::Duration.parse("PT0.5S", precision: :exact).in_seconds
  end

  def test_a_calendar_period_is_not_a_duration
    %w[P1Y P1M P1W].each do |value|
      assert_raises(Horologium::ParseError) do
        Horologium::Duration.parse(value)
      end
    end
  end

  def test_a_duration_with_no_fields_is_refused
    %w[P PT].each do |value|
      assert_raises(Horologium::ParseError) do
        Horologium::Duration.parse(value)
      end
    end
  end

  def test_a_fraction_above_the_smallest_field_is_refused
    assert_raises(Horologium::ParseError) do
      Horologium::Duration.parse("PT1.5H1M")
    end
  end

  def test_it_refuses_something_that_is_not_a_duration_string
    [nil, 5, "banana", "1H", "PT1X"].each do |value|
      assert_raises(Horologium::ParseError) do
        Horologium::Duration.parse(value)
      end
    end
  end

  def test_it_writes_an_iso_8601_duration
    assert_equal "PT4H5M6S", Horologium::Duration.seconds(14_706).to_iso8601
  end

  def test_it_writes_whole_days_as_a_day_field
    assert_equal "P3D", Horologium::Duration.seconds(259_200).to_iso8601
  end

  def test_it_writes_no_time_at_all
    assert_equal "PT0S", Horologium::Duration.zero.to_iso8601
  end

  def test_it_writes_a_fraction_of_a_second
    assert_equal "PT0.5S", Horologium::Duration.seconds(0.5).to_iso8601
  end

  def test_it_writes_a_negative_duration
    assert_equal "-PT1H", Horologium::Duration.seconds(-3600).to_iso8601
  end

  def test_a_duration_on_the_nanosecond_grid_reads_back
    [0, 1, -1, 0.5, 14_706, 259_200, 93_784.5, 86_401, -3600].each do |seconds|
      duration = Horologium::Duration.seconds(seconds, precision: :exact)

      assert_equal duration,
        Horologium::Duration.parse(duration.to_iso8601, precision: :exact)
    end
  end

  # The string holds nanoseconds. A third of a second has no finite decimal
  # form at any resolution, so it is written to the grid and reads back as the
  # grid value, and #to_r is what keeps the whole of it.
  def test_a_duration_finer_than_a_nanosecond_is_written_to_the_grid
    third = Horologium::Duration.seconds(1, precision: :exact) / 3

    assert_equal "PT0.333333333S", third.to_iso8601
    assert_equal Rational(333_333_333, 1_000_000_000),
      Horologium::Duration.parse(third.to_iso8601, precision: :exact).to_r
  end

  def test_a_duration_under_half_a_nanosecond_writes_as_none_at_all
    quarter = Horologium::Duration.nanoseconds(
      Rational(1, 4),
      precision: :exact
    )

    assert_equal "PT0S", quarter.to_iso8601
  end

  def test_a_trailing_t_opening_no_fields_is_refused
    %w[P1DT P1.5DT].each do |value|
      assert_raises(Horologium::ParseError) do
        Horologium::Duration.parse(value)
      end
    end
  end

  def test_a_scalar_that_overflows_a_float_is_refused_at_standard
    assert_raises(Horologium::InvalidValueError) do
      Horologium::Duration.seconds(1) * 10**400
    end
  end

  def test_a_scalar_that_overflows_a_float_is_held_at_exact
    scaled = Horologium::Duration.seconds(1, precision: :exact) * 10**400

    assert_equal 10**400, scaled.to_r
  end
end
