# frozen_string_literal: true

require "test_helper"
require "json"

# Cross-checks the TAI to TT, TDB, TCG, TCB and GPS conversions against
# astropy. The reference values live in
# test/fixtures/scale_conversions.json, frozen from astropy with the versions
# and method the file records.
#
# Each Julian Date is compared as its two parts turned into an exact Rational,
# not as a single Float. A Float Julian Date at a modern date is only good to
# tens of microseconds, so a single-Float comparison could not see a
# nanosecond error; the two parts keep the check below a nanosecond, which is
# where the conversions are meant to be.
class TestScaleConversions < Minitest::Test
  FIXTURE = JSON.parse(
    File.read(File.expand_path("../fixtures/scale_conversions.json", __dir__))
  ).freeze

  # One nanosecond, in days. The largest gap from the astropy reference
  # measured across the cases is a few thousandths of this.
  TOLERANCE = Rational(1, 86_400 * 1_000_000_000)

  def teardown
    Horologium.reset_configuration!
  end

  def test_the_fixture_lists_reference_cases
    refute_empty FIXTURE["cases"]
  end

  def test_it_converts_tai_to_tt_matching_astropy
    assert_matches_reference("tt")
  end

  def test_it_converts_tai_to_tdb_matching_astropy
    assert_matches_reference("tdb")
  end

  def test_it_converts_tai_to_tcg_matching_astropy
    assert_matches_reference("tcg")
  end

  def test_it_converts_tai_to_tcb_matching_astropy
    assert_matches_reference("tcb")
  end

  def test_it_converts_tai_to_gps_matching_astropy
    assert_matches_reference("gps")
  end

  private

  # Builds each instant from the TAI Julian Date in the fixture, reads it in
  # the scale, and checks it against the astropy value within {TOLERANCE}, at
  # both precisions.
  #
  # @param scale [String] "tt", "tdb", "tcg", "tcb" or "gps"
  def assert_matches_reference(scale)
    FIXTURE["cases"].each do |reference|
      tai = reference["tai"]
      jd1, jd2 = reference[scale]

      %i[standard exact].each do |precision|
        instant = Horologium::Instant.from_julian_date(
          tai[0],
          tai[1],
          scale: :tai,
          precision: precision
        )
        expected = jd1.to_r + jd2.to_r
        actual = instant
          .as(:julian_date, scale: scale.to_sym, as: :two_part)
          .to_r
        delta = actual - expected

        assert_operator delta.abs, :<=, TOLERANCE,
          "#{scale} at #{precision} for TAI #{tai[0]} + #{tai[1]} is off by " \
          "#{(delta * 86_400 * 1_000_000_000).to_f} ns"
      end
    end
  end
end
