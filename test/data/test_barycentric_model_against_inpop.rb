# frozen_string_literal: true

require "test_helper"
require "json"

class TestDataBarycentricModelAgainstInpop < Minitest::Test
  FIXTURE = JSON.parse(
    File.read(File.expand_path("../fixtures/inpop_time.json", __dir__))
  ).freeze

  # 2000-01-01 and 2050-01-01 at 0h TDB.
  PRESENT_DAY = (2_451_544.5..2_469_807.5)

  class << self
    def differences
      @differences ||= FIXTURE["cases"].to_h do |julian_date, tt_minus_tdb|
        [julian_date, difference(julian_date, tt_minus_tdb)]
      end
    end

    private

    def difference(julian_date, tt_minus_tdb)
      tdb_minus_tt =
        Horologium::Data::BarycentricModel.tdb_minus_tt(julian_date)

      (tdb_minus_tt + tt_minus_tdb) * 1e9
    end
  end

  def test_the_fixture_lists_reference_cases
    refute_empty FIXTURE["cases"]
  end

  def test_it_stays_within_70_ns_of_inpop_from_1900_to_2100
    assert_operator max(differences), :<, 70
  end

  def test_its_rms_difference_from_inpop_from_1900_to_2100_is_below_35_ns
    assert_operator rms(differences), :<, 35
  end

  def test_it_stays_within_45_ns_of_inpop_from_2000_to_2050
    assert_operator max(differences(PRESENT_DAY)), :<, 45
  end

  def test_its_rms_difference_from_inpop_from_2000_to_2050_is_below_31_ns
    assert_operator rms(differences(PRESENT_DAY)), :<, 31
  end

  def test_it_agrees_with_inpop_within_5_ns_on_1977_01_01
    assert_operator self.class.differences.fetch(2_443_144.5).abs, :<, 5
  end

  private

  def differences(range = nil)
    all = self.class.differences
    return all.values unless range

    all.filter_map { |julian_date, value| value if range.cover?(julian_date) }
  end

  def max(values)
    values.map(&:abs).max
  end

  def rms(values)
    Math.sqrt(values.sum { |value| value * value } / values.size)
  end
end
