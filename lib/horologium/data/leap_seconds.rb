# frozen_string_literal: true

require "iers"

module Horologium
  module Data
    # The leap seconds, TAI - UTC, from the iers gem. {Scales::UTC} reads this
    # to convert between UTC and TAI, and it is the default source. A caller
    # with its own leap second data, a frozen bulletin or an alternative feed,
    # can put another source in its place through
    # {Configuration#leap_second_source}, as long as it answers {tai_utc_at}.
    #
    # The lookup is by whole day. TAI - UTC changes at 0h UTC, so a scale asks
    # for the offset at the start of a day, and iers reads it from the bundled
    # table with no network access.
    module LeapSeconds
      # The days between a Julian Date and a Modified Julian Date, less the
      # half day that puts a Julian Day Number, which counts from noon, onto
      # the midnight a Modified Julian Date counts from. Subtracting it from a
      # Julian Day Number gives the integer Modified Julian Date of that day's
      # 0h, the shape iers reads.
      #
      # @api private
      MJD_OFFSET = 2_400_001

      class << self
        # TAI - UTC at 0h UTC of a day, the number of seconds TAI is ahead of
        # UTC. From 1972 it is a whole number of seconds, an Integer; between
        # 1961 and 1972, when UTC drifted, it is a fraction of a second, a
        # Rational. Either is exact.
        #
        # @param day_number [Integer] the Julian Day Number of the day
        # @return [Integer, Rational] TAI - UTC in seconds
        # @raise [IERS::OutOfRangeError] before 1961, where TAI - UTC is not
        #   defined; {Scales::UTC} stops at 1972 before this is reached
        def tai_utc_at(day_number)
          IERS::LeapSecond.at(mjd: day_number - MJD_OFFSET)
        end
      end
    end
  end
end
