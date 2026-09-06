# frozen_string_literal: true

require "test_helper"
require "json"

# Cross-checks the TAI to UT1 conversion against astropy. UT1 is the one scale
# that rests on published data, and astropy and the iers gem read different
# tables, so the fixture carries the delta T both sides are to use and the
# test injects it. What is compared is the arithmetic: astropy reaches UT1 as
# UTC + delta UT1, Horologium as TT - delta T.
class TestUT1Conversions < Minitest::Test
  FIXTURE = JSON.parse(
    File.read(File.expand_path("../fixtures/ut1_conversions.json", __dir__))
  ).freeze

  # A source answering with one fixed delta T, so the conversion is fed the
  # same number astropy was.
  class FixedDeltaT
    def initialize(seconds)
      @seconds = seconds
    end

    def delta_t_at(_julian_date)
      @seconds
    end

    def provenance_at(_julian_date)
      :measured
    end
  end

  def teardown
    Horologium.reset_configuration!
  end

  def test_the_fixture_lists_reference_cases
    refute_empty FIXTURE["cases"]
  end

  def test_it_converts_tai_to_ut1_matching_astropy
    FIXTURE["cases"].each do |reference|
      tai = reference["tai"]
      jd1, jd2 = reference["ut1"]
      expected = jd1.to_r + jd2.to_r

      %i[standard exact].each do |precision|
        Horologium.reset_configuration!
        Horologium.configure do |c|
          c.eop_source = FixedDeltaT.new(reference["delta_t"])
        end

        actual = Horologium::Instant
          .from_julian_date(tai[0], tai[1], scale: :tai, precision: precision)
          .as(:julian_date, scale: :ut1, as: :two_part)
          .to_r
        delta = actual - expected

        assert_operator delta.abs, :<=, Rational(1, 86_400 * 1_000_000_000),
          "ut1 at #{precision} for TAI #{tai[0]} + #{tai[1]} is off by " \
          "#{(delta * 86_400 * 1_000_000_000).to_f} ns"
      end
    end
  end

  def test_it_reads_ut1_back_into_tai_across_the_reference_cases
    FIXTURE["cases"].each do |reference|
      tai = reference["tai"]
      Horologium.reset_configuration!
      Horologium.configure do |c|
        c.eop_source = FixedDeltaT.new(reference["delta_t"])
      end

      instant = Horologium::Instant.from_julian_date(
        tai[0], tai[1], scale: :tai, precision: :exact
      )
      round_trip = Horologium::Instant.from_julian_date(
        instant.as(:julian_date, scale: :ut1, as: :rational),
        scale: :ut1,
        precision: :exact
      )

      assert_equal instant, round_trip
    end
  end
end
