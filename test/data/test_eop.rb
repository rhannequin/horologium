# frozen_string_literal: true

require "test_helper"

# The Earth orientation data behind UT1, delta T being TT - UT1. The measured
# series answers where it reaches; the Espenak and Meeus polynomial answers
# the rest of 1800 to 1986.
class TestDataEop < Minitest::Test
  def test_delta_t_at_j2000_is_about_64_seconds
    assert_in_delta 63.83,
      Horologium::Data::Eop.delta_t_at(2_451_545.0),
      0.01
  end

  def test_delta_t_grows_across_the_twentieth_century
    assert_operator Horologium::Data::Eop.delta_t_at(2_415_020.0),
      :<,
      Horologium::Data::Eop.delta_t_at(2_451_545.0)
  end

  def test_a_date_the_series_observed_is_measured
    assert_equal :measured,
      Horologium::Data::Eop.provenance_at(2_458_849.5)
  end

  def test_a_date_before_the_series_is_estimated
    assert_equal :estimated,
      Horologium::Data::Eop.provenance_at(2_415_020.0)
  end

  # 1972 belongs to the polynomial, since the published series starts in 1973.
  # It read as measured, and raised, before iers moved the seam onto the data.
  def test_a_1972_date_is_estimated_rather_than_refused
    assert_equal :estimated,
      Horologium::Data::Eop.provenance_at(2_441_500.0)
  end

  # The series runs about a year ahead of itself in predictions, so a date a
  # few months out is predicted whatever vintage of the data is loaded. Fixing
  # a date here instead would go stale the moment the data caught up with it.
  def test_a_date_the_series_predicts_is_extrapolated
    two_hundred_days_out = Time.now.to_r / 86_400 + 2_440_587.5 + 200

    assert_equal :extrapolated,
      Horologium::Data::Eop.provenance_at(two_hundred_days_out)
  end

  def test_it_refuses_a_date_neither_source_reaches
    assert_raises(IERS::OutOfRangeError) do
      Horologium::Data::Eop.delta_t_at(2_378_000.0)
    end
  end
end
