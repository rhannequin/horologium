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
    # The lookup is by day. TAI - UTC steps at 0h UTC, so a scale asks for the
    # offset at the start of a day; before 1972 it drifts through the day too,
    # so the scale also asks part way through one. iers reads either from the
    # bundled table with no network access.
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
        # TAI - UTC at a point in UTC, the number of seconds TAI is ahead of
        # UTC. From 1972 it is a whole number of seconds, an Integer; between
        # 1961 and 1972, when UTC drifted, it is a fraction of a second, a
        # Rational. Either is exact. The point is a day by its Julian Day
        # Number, or part way through one where a fraction is added.
        #
        # @param day_number [Integer, Rational] the Julian Day Number of the
        #   day, or a point through it
        # @return [Integer, Rational] TAI - UTC in seconds
        # @raise [IERS::OutOfRangeError] before 1961, where TAI - UTC is not
        #   defined; {Scales::UTC} stops there before this is reached
        def tai_utc_at(day_number)
          IERS::LeapSecond.at(mjd: day_number - MJD_OFFSET)
        end

        # The date the leap second data stops vouching for itself, from the
        # file's own header, or nil when it states none. A date past it might
        # miss a leap second announced since the file was made, which is what
        # marks a UTC reading there +:extrapolated+.
        #
        # @return [Date, nil]
        def expires_on
          IERS::LeapSecond.expires_on
        end
      end
    end
  end
end
