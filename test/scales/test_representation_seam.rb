# frozen_string_literal: true

require "test_helper"

# Proves the civil and ISO representations read the day length and the zone
# designator from the scale, not from a constant of their own. A fake scale
# gives answers no real scale gives, and the representations follow them. UTC
# is the scale that will give the real leap-second answers; this checks the
# seam without waiting for it.
class TestRepresentationSeam < Minitest::Test
  # An identity scale, so a fake-scale Julian Date is a TAI one, and the only
  # thing that sets it apart from TAI is a 90,000-second day and an ISO string
  # ending in "#". Neither is physical; they only have to be unlike every
  # built-in scale, so a representation reading them is visible.
  class FakeScale < Horologium::Scales::Base
    LONG_DAY = 90_000

    class << self
      def from_reference(value, _precision)
        value
      end

      def to_reference(value, _precision)
        value
      end

      def seconds_in_day(_day_number)
        LONG_DAY
      end

      def zone_designator
        "#"
      end
    end
  end

  def setup
    Horologium.configure do |config|
      config.register_scale(:fake, FakeScale)
    end
  end

  def teardown
    Horologium.reset_configuration!
  end

  def test_render_maps_the_fraction_through_the_scales_day_length
    # A Julian Date of x.0 is midday, half a day on from the midnight the
    # calendar counts. Half of a 90,000-second day is 45,000 s = 12:30:00,
    # where an 86,400-second day would read 12:00:00.
    civil = Horologium::Instant
      .from_julian_date(2_460_000.0, scale: :fake)
      .as(:civil, scale: :fake)

    assert_equal 12, civil.hour
    assert_equal 30, civil.minute
    assert_equal 0, civil.second
  end

  def test_parse_places_the_time_by_the_scales_day_length
    fake = Horologium::Instant.from_civil(2_025, 5, 1, 12, 30, 0, scale: :fake)

    # The scale is TAI but for its day length, so the same fields landing on a
    # different instant can only be the 90,000-second day at work.
    refute_equal Horologium::Instant.from_civil(
      2_025, 5, 1, 12, 30, 0,
      scale: :tai
    ),
      fake

    civil = fake.as(:civil, scale: :fake)

    assert_equal [12, 30, 0], [civil.hour, civil.minute, civil.second]
  end

  def test_render_and_parse_round_trip_through_the_seam
    instant = Horologium::Instant.from_civil(
      2_025, 5, 1, 20, 15, 30,
      scale: :fake,
      precision: :exact
    )
    civil = instant.as(:civil, scale: :fake, as: :rational)

    assert_equal instant,
      Horologium::Instant.from_civil(civil, scale: :fake, precision: :exact)
  end

  def test_iso_writes_the_scales_zone_designator
    string = Horologium::Instant
      .from_julian_date(2_460_000.5, scale: :fake)
      .as(:iso8601, scale: :fake)

    assert string.end_with?("#"),
      "expected the fake scale's designator, got #{string.inspect}"
  end
end
