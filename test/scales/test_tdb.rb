# frozen_string_literal: true

require "test_helper"

class TestScalesTDB < Minitest::Test
  def test_tdb_is_registered
    instant = Horologium::Instant.from_julian_date(2_451_545.0, scale: :tdb)

    assert_instance_of Horologium::ScaleReading, instant.to(:tdb)
  end

  def test_reading_tai_in_tdb_shifts_the_tt_date_by_the_model_difference
    instant = Horologium::Instant.from_julian_date(2_460_796.5, scale: :tt)

    assert_in_delta 2_460_796.500_000_016_8,
      instant.to(:tdb).as(:julian_date),
      1e-9
  end

  def test_a_tdb_julian_date_reads_back_as_the_one_it_was_given
    instant = Horologium::Instant.from_julian_date(
      2_460_796.5,
      scale: :tdb,
      precision: :exact
    )

    assert_in_delta 2_460_796.5,
      instant.as(:julian_date, scale: :tdb),
      1e-9
  end

  def test_a_standard_round_trip_stays_within_a_nanosecond
    value = Horologium::Numeric::TwoPartFloat.new(2_460_796.5)

    reading = Horologium::Scales::TDB.from_reference(value, :standard)
    round_trip = Horologium::Scales::TDB.to_reference(reading, :standard)

    assert_operator (round_trip.to_r - value.to_r).abs, :<,
      Rational(1, 86_400 * 1_000_000_000)
  end

  def test_a_standard_reading_stays_a_two_part_float
    value = Horologium::Numeric::TwoPartFloat.new(2_451_545.0)

    reading = Horologium::Scales::TDB.from_reference(value, :standard)

    assert_instance_of Horologium::Numeric::TwoPartFloat, reading
  end

  def test_an_exact_reading_stays_exact
    value = Horologium::Numeric::Exact.new(2_451_545.0)

    reading = Horologium::Scales::TDB.from_reference(value, :exact)

    assert_instance_of Horologium::Numeric::Exact, reading
  end

  def test_an_exact_reading_keeps_the_model_result_without_extra_rounding
    tai = Horologium::Numeric::Exact.new(2_451_545.0)
    in_tt = Horologium::Scales::TT.from_reference(tai, :exact)
    seconds = Horologium::Data::BarycentricModel.tdb_minus_tt(in_tt.to_f)

    reading = Horologium::Scales::TDB.from_reference(tai, :exact)

    assert_equal in_tt.to_r + Rational(seconds) / 86_400, reading.to_r
  end

  def test_it_rejects_an_unrecognised_precision
    value = Horologium::Numeric::TwoPartFloat.new(2_451_545.0)

    assert_raises(Horologium::UnknownPrecisionError) do
      Horologium::Scales::TDB.from_reference(value, :fast)
    end
  end
end
