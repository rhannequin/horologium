# frozen_string_literal: true

require "test_helper"

# TCG is the coordinate time of a frame moving with the Earth but outside its
# gravity well, so it runs ahead of TT at the fixed rate L_G. The two were set
# to read the same at the Julian Date 2443144.5 TAI, 1977-01-01 00:00:00 TAI,
# which is 2443144.5003725 in TT.
class TestScalesTCG < Minitest::Test
  ORIGIN_IN_TT = Rational(24_431_445_003_725, 10_000_000)

  A_NANOSECOND_IN_DAYS = Rational(1, 86_400 * 1_000_000_000)

  def test_the_defining_constant_is_l_g
    assert_equal Rational(6_969_290_134, 10**19), Horologium::Scales::TCG::L_G
  end

  def test_tcg_and_tt_read_the_same_at_the_origin
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::TCG.from_reference(value, :exact)

    assert_equal ORIGIN_IN_TT, reading.to_r
  end

  def test_tcg_gains_on_tt_at_the_rate_l_g_over_one_minus_l_g
    value = Horologium::Numeric::Exact.new(2_460_000.5)

    in_tt = Horologium::Scales::TT.from_reference(value, :exact).to_r
    in_tcg = Horologium::Scales::TCG.from_reference(value, :exact).to_r
    l_g = Horologium::Scales::TCG::L_G

    assert_equal l_g / (1 - l_g), (in_tcg - in_tt) / (in_tt - ORIGIN_IN_TT)
  end

  def test_tcg_gains_about_22_milliseconds_a_julian_year
    origin = Horologium::Numeric::Exact.new(2_443_144.5)
    a_year_on = Horologium::Numeric::Exact.new(2_443_144.5 + 365.25)

    gain = Horologium::Scales::TCG.from_reference(a_year_on, :exact).to_r -
      Horologium::Scales::TT.from_reference(a_year_on, :exact).to_r
    at_origin = Horologium::Scales::TCG.from_reference(origin, :exact).to_r -
      Horologium::Scales::TT.from_reference(origin, :exact).to_r

    assert_in_delta 0.021993,
      ((gain - at_origin) * Horologium::Duration::SECONDS_PER_DAY).to_f,
      0.000001
  end

  def test_reading_tcg_back_into_tai_returns_the_value_it_came_from
    value = Horologium::Numeric::Exact.new(2_460_000.5)

    reading = Horologium::Scales::TCG.from_reference(value, :exact)

    assert_equal value.to_r,
      Horologium::Scales::TCG.to_reference(reading, :exact).to_r
  end

  def test_a_standard_round_trip_stays_within_a_nanosecond
    value = Horologium::Numeric::TwoPartFloat.new(2_460_000.5)

    reading = Horologium::Scales::TCG.from_reference(value, :standard)
    round_trip = Horologium::Scales::TCG.to_reference(reading, :standard)

    assert_operator (round_trip.to_r - value.to_r).abs, :<,
      A_NANOSECOND_IN_DAYS
  end

  def test_a_standard_reading_stays_within_a_nanosecond_of_the_exact_one
    exact = Horologium::Numeric::Exact.new(2_460_000.5)
    standard = Horologium::Numeric::TwoPartFloat.new(2_460_000.5)

    from_exact = Horologium::Scales::TCG.from_reference(exact, :exact)
    from_standard = Horologium::Scales::TCG.from_reference(standard, :standard)

    assert_operator (from_standard.to_r - from_exact.to_r).abs, :<,
      A_NANOSECOND_IN_DAYS
  end

  def test_a_standard_reading_stays_a_two_part_float
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    reading = Horologium::Scales::TCG.from_reference(value, :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, reading
  end

  def test_an_exact_reading_stays_exact
    value = Horologium::Numeric::Exact.new(2_443_144.5)

    reading = Horologium::Scales::TCG.from_reference(value, :exact)

    assert_instance_of Horologium::Numeric::Exact, reading
  end

  # At the origin TCG reads the same as TT, and TT there is 32.184 seconds
  # past midnight, so the origin epoch can be built from its TCG fields.
  def test_an_instant_can_be_built_from_tcg_calendar_fields
    instant = Horologium::Instant.from_tcg(
      1977, 1, 1, 0, 0, Rational(32_184, 1_000),
      precision: :exact
    )

    assert_equal Horologium::Epochs::TT_TCG_TCB_ORIGIN, instant
  end

  def test_it_rejects_an_unrecognised_precision
    value = Horologium::Numeric::TwoPartFloat.new(2_443_144.5)

    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Scales::TCG.from_reference(value, :fast)
    end
  end
end
