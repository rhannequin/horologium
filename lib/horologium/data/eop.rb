# frozen_string_literal: true

require "iers"

module Horologium
  module Data
    # The Earth orientation data, from the iers gem. {Scales::UT1} reads this to
    # convert between UT1 and the continuous scales, and it is the default
    # source.
    #
    # Source:
    #  Title: Polynomial expressions for Delta T, 1800 onward
    #  Authors: Fred Espenak and Jean Meeus
    #  Notes: the measured series comes from the IERS, via the iers gem
    module Eop
      # The days between a Julian Date and a Modified Julian Date, the shape
      # iers reads. Unlike {LeapSeconds}, which asks for a day and gets a
      # value that steps at its 0h, delta T is interpolated, so the fraction
      # of the day is kept and this is the plain offset rather than one that
      # also lands on midnight.
      #
      # @api private
      MJD_OFFSET = 2_400_000.5

      class << self
        # TT - UT1 in SI seconds at a point in time, given as a Julian Date.
        #
        # @param julian_date [Float] the Julian Date to read at
        # @return [Float] TT - UT1 in seconds
        # @raise [IERS::OutOfRangeError] where neither source reaches the
        #   date: before the polynomial starts in 1800, and after the
        #   published series ends, the two together covering everything in
        #   between
        def delta_t_at(julian_date)
          IERS::DeltaT.at(mjd: julian_date - MJD_OFFSET).delta_t
        end

        # The Julian Date the published series vouches through, its last entry.
        #
        # @return [Float, nil] the Julian Date of the last entry, or nil where
        #   the series has no entries and there is no horizon to report
        def covers_until
          IERS::Data.finals_entries
            .last(1)
            .map { |entry| entry.mjd + MJD_OFFSET }
            .first
        end

        # How the delta T at a point was arrived at.
        #
        # @param julian_date [Float] the Julian Date to read at
        # @return [Symbol] +:measured+, +:extrapolated+ or +:estimated+
        # @raise [IERS::OutOfRangeError] where delta T is not available
        def provenance_at(julian_date)
          mjd = julian_date - MJD_OFFSET
          return :estimated unless IERS::DeltaT.at(mjd: mjd).measured?

          case IERS::UT1.at(mjd: mjd).data_quality
          when :predicted then :extrapolated
          else :measured
          end
        end
      end
    end
  end
end
