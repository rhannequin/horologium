# frozen_string_literal: true

require "test_helper"

# The reference values are geocentric, from pyerfa 2.0.1.5:
# erfa.dtdb(tt_julian_date, 0.0, 0.0, 0.0, 0.0, 0.0), which zeroes the observer
# terms and leaves the Fairhead & Bretagnon series alone.
class TestDataBarycentricModel < Minitest::Test
  def test_it_matches_erfa_at_j2000
    assert_in_delta(-9.930719894379447e-05,
      Horologium::Data::BarycentricModel.tdb_minus_tt(2_451_545.0),
      1e-13)
  end

  def test_it_matches_erfa_at_a_modern_date
    assert_in_delta 0.0014650900971434394,
      Horologium::Data::BarycentricModel.tdb_minus_tt(2_460_796.5),
      1e-13
  end

  def test_it_matches_erfa_a_century_back
    assert_in_delta(-3.33217401016821e-05,
      Horologium::Data::BarycentricModel.tdb_minus_tt(2_415_020.0),
      1e-13)
  end

  def test_it_matches_erfa_a_century_ahead
    assert_in_delta(-8.99476629850571e-05,
      Horologium::Data::BarycentricModel.tdb_minus_tt(2_488_069.5),
      1e-13)
  end

  def test_it_agrees_with_the_usno_short_formula
    dates.each do |julian_date|
      assert_in_delta usno(julian_date),
        Horologium::Data::BarycentricModel.tdb_minus_tt(julian_date),
        1e-5
    end
  end

  def test_the_difference_stays_within_two_milliseconds
    dates.each do |julian_date|
      assert_operator(
        Horologium::Data::BarycentricModel.tdb_minus_tt(julian_date).abs,
        :<,
        2e-3
      )
    end
  end

  private

  def dates
    [2_451_545.0, 2_460_796.5, 2_455_197.5, 2_415_020.0, 2_488_069.5]
  end

  def usno(julian_date)
    t = (julian_date - 2_451_545.0) / 36_525.0
    0.001657 * Math.sin(628.3076 * t + 6.2401) +
      0.000022 * Math.sin(575.3385 * t + 4.2970) +
      0.000014 * Math.sin(1256.6152 * t + 6.1969) +
      0.000005 * Math.sin(606.9777 * t + 4.0212) +
      0.000005 * Math.sin(52.9691 * t + 0.4444) +
      0.000002 * Math.sin(21.3299 * t + 5.5431) +
      0.000010 * t * Math.sin(628.3076 * t + 4.2490)
  end
end
