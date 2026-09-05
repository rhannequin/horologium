# frozen_string_literal: true

require "test_helper"

# TCB is the coordinate time of a frame at the barycentre of the solar system,
# so it runs ahead of TDB at the fixed rate L_B, about half a second a year.
# The TCB to TDB edge is exact; the rest of the way to TAI goes through TDB,
# which rests on the floating-point barycentric model.
class TestScalesTCB < Minitest::Test
  A_NANOSECOND_IN_DAYS = Rational(1, 86_400 * 1_000_000_000)

  def test_the_defining_constant_is_l_b
    assert_equal Rational(1_550_519_768, 10**17), Horologium::Scales::TCB::L_B
  end

  def test_the_tdb_offset_is_minus_65_point_5_microseconds
    assert_equal Rational(-655, 10**7), Horologium::Scales::TCB::TDB_0
  end

  def test_tcb_gains_on_tdb_at_the_rate_l_b_over_one_minus_l_b
    value = Horologium::Numeric::Exact.new(2_460_000.5)
    origin = Horologium::Scales::TT_TCG_TCB_ORIGIN_JULIAN_DATE
    offset = Horologium::Scales::TCB::TDB_0_IN_DAYS

    in_tdb = Horologium::Scales::TDB.from_reference(value, :exact).to_r
    in_tcb = Horologium::Scales::TCB.from_reference(value, :exact).to_r
    l_b = Horologium::Scales::TCB::L_B

    assert_equal l_b / (1 - l_b),
      (in_tcb - (in_tdb - offset)) / ((in_tdb - offset) - origin)
  end

  def test_tcb_gains_about_half_a_second_a_julian_year
    origin = Horologium::Numeric::Exact.new(2_443_144.5)
    a_year_on = Horologium::Numeric::Exact.new(2_443_144.5 + 365.25)

    gain = Horologium::Scales::TCB.from_reference(a_year_on, :exact).to_r -
      Horologium::Scales::TDB.from_reference(a_year_on, :exact).to_r
    at_origin = Horologium::Scales::TCB.from_reference(origin, :exact).to_r -
      Horologium::Scales::TDB.from_reference(origin, :exact).to_r

    assert_in_delta 0.4894,
      ((gain - at_origin) * Horologium::Duration::SECONDS_PER_DAY).to_f,
      0.0001
  end

  # At the origin the two part by TDB_0, but not to the last bit: TDB there is
  # a few microseconds from the origin Julian Date, because the barycentric
  # model is not zero at that date, and the rate applied over those
  # microseconds leaves a residue. It is about 5e-17 seconds, some fourteen
  # orders of magnitude below the offset it perturbs.
  def test_tcb_and_tdb_part_by_the_tdb_offset_at_the_origin
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    in_tdb = Horologium::Scales::TDB.from_reference(value, :exact).to_r
    in_tcb = Horologium::Scales::TCB.from_reference(value, :exact).to_r
    parting = (in_tdb - in_tcb) * Horologium::Duration::SECONDS_PER_DAY

    assert_operator (parting - Horologium::Scales::TCB::TDB_0).abs, :<,
      Rational(1, 10**15)
  end

  def test_reading_tcb_back_into_tai_returns_the_value_it_came_from
    value = Horologium::Numeric::Exact.new(2_460_000.5)

    reading = Horologium::Scales::TCB.from_reference(value, :exact)
    round_trip = Horologium::Scales::TCB.to_reference(reading, :exact)

    assert_operator (round_trip.to_r - value.to_r).abs, :<,
      A_NANOSECOND_IN_DAYS
  end

  def test_a_standard_round_trip_stays_within_a_nanosecond
    value = Horologium::Numeric::TwoPartFloat.new(2_460_000.5)

    reading = Horologium::Scales::TCB.from_reference(value, :standard)
    round_trip = Horologium::Scales::TCB.to_reference(reading, :standard)

    assert_operator (round_trip.to_r - value.to_r).abs, :<,
      A_NANOSECOND_IN_DAYS
  end

  def test_a_standard_reading_stays_within_a_nanosecond_of_the_exact_one
    exact = Horologium::Numeric::Exact.new(2_460_000.5)
    standard = Horologium::Numeric::TwoPartFloat.new(2_460_000.5)

    from_exact = Horologium::Scales::TCB.from_reference(exact, :exact)
    from_standard = Horologium::Scales::TCB.from_reference(standard, :standard)

    assert_operator (from_standard.to_r - from_exact.to_r).abs, :<,
      A_NANOSECOND_IN_DAYS
  end

  def test_a_standard_reading_stays_a_two_part_float
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::TCB.from_reference(value, :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, reading
  end

  def test_an_exact_reading_stays_exact
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::TCB.from_reference(value, :exact)

    assert_instance_of Horologium::Numeric::Exact, reading
  end

  def test_an_instant_can_be_built_from_tcb_calendar_fields
    instant = Horologium::Instant.from_tcb(2025, 5, 1, 12, precision: :exact)

    assert_equal "2025-05-01T12:00:00.000000000",
      instant.to(:tcb).as(:iso8601)
  end

  def test_it_rejects_an_unrecognised_precision
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Scales::TCB.from_reference(value, :fast)
    end
  end
end
