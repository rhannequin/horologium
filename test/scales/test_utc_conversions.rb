# frozen_string_literal: true

require "test_helper"
require "json"

# Cross-checks the UTC to TAI conversion against astropy, the leap second
# included. The reference values live in test/fixtures/utc_conversions.json,
# frozen from astropy with the versions and method the file records.
#
# TAI is compared as its two parts turned into an exact Rational, not as a
# single Float, so the check stays below a nanosecond where a single Float
# would lose tens of microseconds.
class TestUtcConversions < Minitest::Test
  FIXTURE = JSON.parse(
    File.read(File.expand_path("../fixtures/utc_conversions.json", __dir__))
  ).freeze

  # One nanosecond, in days.
  TOLERANCE = Rational(1, 86_400 * 1_000_000_000)

  def teardown
    Horologium.reset_configuration!
  end

  def test_the_fixture_lists_reference_cases
    refute_empty FIXTURE["cases"]
  end

  def test_it_converts_utc_to_tai_matching_astropy
    FIXTURE["cases"].each do |reference|
      year, month, day, hour, minute, second = reference["utc"]
      jd1, jd2 = reference["tai"]

      instant = Horologium::Instant.from_utc(
        year,
        month,
        day,
        hour,
        minute,
        second(second),
        precision: :exact
      )
      expected = jd1.to_r + jd2.to_r
      actual = instant
        .as(:julian_date, scale: :tai, as: :two_part)
        .to_r
      delta = actual - expected

      assert_operator delta.abs, :<=, TOLERANCE,
        "UTC #{reference["utc"].join(" ")} is off by " \
        "#{(delta * 86_400 * 1_000_000_000).to_f} ns"
    end
  end

  private

  # The second field, exact: a whole second is an Integer, a fractional one a
  # Rational, so no digit is lost before the library reads it.
  #
  # @param text [String] the second, as the fixture spells it
  # @return [Integer, Rational]
  def second(text)
    text.include?(".") ? Rational(text) : Integer(text, 10)
  end
end
