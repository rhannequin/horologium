# frozen_string_literal: true

require "test_helper"

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

  def test_a_1972_date_is_estimated_rather_than_refused
    assert_equal :estimated,
      Horologium::Data::Eop.provenance_at(2_441_500.0)
  end

  def test_a_date_the_series_predicts_is_extrapolated
    last_day = (60_000..70_000).bsearch { |mjd| !series_reaches?(mjd) } - 1

    assert_equal :extrapolated,
      Horologium::Data::Eop.provenance_at(last_day + 2_400_000.5)
  end

  def test_it_reports_the_date_the_series_reaches
    last_day = (60_000..70_000).bsearch { |mjd| !series_reaches?(mjd) } - 1

    assert_in_delta last_day + 2_400_000.5,
      Horologium::Data::Eop.covers_until,
      0.5
  end

  def test_it_refuses_a_date_neither_source_reaches
    assert_raises(IERS::OutOfRangeError) do
      Horologium::Data::Eop.delta_t_at(2_378_000.0)
    end
  end

  private

  def series_reaches?(mjd)
    IERS::UT1.at(mjd: mjd)
    true
  rescue IERS::OutOfRangeError
    false
  end
end
