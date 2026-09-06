# frozen_string_literal: true

require "iers"

module Horologium
  module Data
    # The Earth orientation data, from the iers gem. {Scales::UT1} reads this
    # to convert between UT1 and the continuous scales, and it is the default
    # source. A caller with its own data, a frozen bulletin or an alternative
    # feed, can put another source in its place through
    # {Configuration#eop_source}, as long as it answers {delta_t_at} and
    # {provenance_at}.
    #
    # The quantity is delta T, TT - UT1, in SI seconds. It is not a constant
    # and not a model: the Earth's rotation is irregular, so delta T is
    # measured and published, and where the measurements do not reach it is
    # estimated from a polynomial fit to eclipse records and old observations.
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
        # The Julian Date is read in UTC where UTC is defined, because that is
        # what the published series is tabulated against; {Scales::UT1} is
        # what decides that and passes the right one. The value is
        # interpolated between daily entries, so a fraction of a day counts.
        #
        # @param julian_date [Float] the Julian Date to read at
        # @return [Float] TT - UT1 in seconds
        # @raise [IERS::OutOfRangeError] before 1800, and through 1972, where
        #   the iers series the measured branch reads has not started
        def delta_t_at(julian_date)
          IERS::DeltaT.at(mjd: julian_date - MJD_OFFSET).delta_t
        end

        # How the delta T at a point was arrived at. +:measured+ where the
        # published series observed it, +:extrapolated+ where the series
        # predicts it, and +:estimated+ where the series does not reach and
        # the polynomial fit answers instead.
        #
        # Which of the two answered is asked of iers rather than worked out
        # from a date here, because the seam sits wherever the loaded series
        # happens to start and moves when that data is replaced.
        #
        # It is read only when it is asked for, not on every reading, so the
        # conversion pays for one lookup rather than two.
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
