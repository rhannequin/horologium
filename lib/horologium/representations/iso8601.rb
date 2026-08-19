# frozen_string_literal: true

module Horologium
  module Representations
    # An instant written as an extended ISO 8601 date and time, in the scale it
    # is read in: +2025-05-01T12:00:00.000000000+. It is a formatting of the
    # calendar date {Civil} reads, so the two agree on every field, and the
    # string is the shape a log, a fixture, or another tool reads.
    #
    # The scale is not written into the string. There is no ISO 8601
    # designator for TAI or TT, and +Z+ means UTC, so a bare time here is a
    # coordinate in the scale you asked for, not a claim about which scale that
    # is. UTC writes the +Z+ that belongs to it, where a leap second and a zero
    # offset are real; the continuous scales carry neither.
    #
    # The fraction of a second is written to nanosecond resolution, nine
    # digits, the resolution the example in the design carries. That is display
    # resolution, not the whole of what an instant holds: for the exact value,
    # read it as a {JulianDate} or a {Civil} with +as: :rational+. On the way
    # in, the parser keeps every digit it is given, unbounded at +:exact+, so a
    # string says as much as it likes and nothing is dropped before the
    # library.
    #
    # @example
    #   instant = Horologium::Instant.from_julian_date(2_443_144.5, scale: :tai)
    #   instant.as(:iso8601, scale: :tai) # => "1977-01-01T00:00:00.000000000"
    #   instant.as(:iso8601, scale: :tt)  # => "1977-01-01T00:00:32.184000000"
    class Iso8601
      # The strict subset of ISO 8601 the parser reads: a full calendar date,
      # and an optional time of day after a +T+, down to an optional fraction
      # of a second and an optional +Z+ or numeric offset. The year is four
      # digits or more, with a minus sign for a year before 1. A numeric offset
      # runs from -23:59 to +23:59. Anything outside that shape is refused
      # rather than read part way: a week date, an ordinal date, a bare hour,
      # a comma for the decimal point, a space for the +T+, an offset out of
      # range.
      #
      # @api private
      PATTERN = /
        \A
        (?<year>-?\d{4,})-(?<month>\d{2})-(?<day>\d{2})
        (?:
          T
          (?<hour>\d{2}):(?<minute>\d{2})
          (?::(?<second>\d{2})(?:\.(?<fraction>\d+))?)?
          (?<zone>Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)?
        )?
        \z
      /x
      private_constant :PATTERN

      # Half a day, the gap between a Julian Date, which starts at noon, and
      # the midnight the calendar counts a day from.
      #
      # @api private
      HALF_DAY = Rational(1, 2)
      private_constant :HALF_DAY

      class << self
        # The reading, written as an ISO 8601 string. The +as+ type a Julian
        # Date chooses does not apply here: an ISO 8601 reading is always a
        # String, so the type is ignored.
        #
        # The instant is rounded to the nearest nanosecond first, so a fraction
        # that would round up to a whole second carries into the clock before
        # the fields are read, and the fields never show a time that does not
        # exist.
        #
        # @param reading [Horologium::ScaleReading] the instant, read in a
        #   scale
        # @param _output [Symbol] ignored; an ISO 8601 reading is a String
        # @return [String] the date and time, in extended ISO 8601
        # @raise [InvalidCivilTimeError] before {Civil::MINIMUM_YEAR}, where
        #   the calendar conversion stops
        # @example
        #   instant = Horologium::Instant.from_julian_date(
        #     2_443_144.5,
        #     scale: :tai
        #   )
        #   instant.to(:tai).as(:iso8601) # => "1977-01-01T00:00:00.000000000"
        def render(reading, _output = :string)
          civil = Civil.render(nanosecond_reading(reading), :rational)
          nanoseconds =
            (civil.second_fraction * Duration::NANOSECONDS_PER_SECOND).round

          # A continuous scale writes no designator, so a bare time is a
          # coordinate in the scale it was read in; UTC writes "Z".
          designator = Horologium
            .configuration
            .scale(reading.scale)
            .zone_designator

          format(
            "%<date>sT%<hour>02d:%<minute>02d:%<second>02d.%<nanoseconds>09d" \
            "%<designator>s",
            date: date(civil),
            hour: civil.hour,
            minute: civil.minute,
            second: civil.second,
            nanoseconds: nanoseconds,
            designator: designator
          )
        end

        # An ISO 8601 string, read as a Julian Date in days, at the precision
        # asked for. This is the way in, where {render} is the way out. The
        # Julian Date is in the scale the string is read in; it is
        # {Instant.from_iso8601} that reads it back in TAI.
        #
        # Nothing is dropped: the date and time become an exact fraction of a
        # day, and every digit of the fraction of a second is kept, unbounded
        # at +:exact+. A numeric offset is subtracted here, in the scale, as
        # plain arithmetic on the fields; it is not a time zone and consults no
        # zone data. It counts against the day's own length, so on a leap
        # second day an offset shifts by SI seconds, not by a stretched
        # fraction of the day.
        #
        # @param value [String] the date and time, in extended ISO 8601
        # @param _low [nil] unused; an ISO 8601 string has no low part
        # @param scale [Class] the scale the string is read in, passed on to
        #   {Civil.parse} to place a leap second
        # @param precision [Symbol] +:standard+ or +:exact+
        # @return [Horologium::Numeric::TwoPartFloat,
        #   Horologium::Numeric::Exact] the Julian Date, in days
        # @raise [ParseError] when the string is not in the subset the parser
        #   reads
        # @raise [InvalidCivilTimeError] when the date and time do not exist
        # @raise [ArgumentError] when the value is not a String
        # @raise [UnknownPrecisionError] when the precision is not recognised
        # @example
        #   Horologium::Representations::Iso8601.parse(
        #     "2016-12-31T23:59:59.5Z",
        #     nil,
        #     Horologium::Scales::TAI,
        #     :exact
        #   )
        def parse(value, _low, scale, precision)
          fields = fields(value)
          in_scale = Civil.parse(fields.fetch(:civil), nil, scale, precision)
          offset_seconds = fields.fetch(:offset_seconds)
          return in_scale if offset_seconds.zero?

          day = (in_scale.to_r + HALF_DAY).floor
          Numeric::Precision.subtract(
            in_scale,
            Numeric::Precision.build(
              Rational(offset_seconds, scale.seconds_in_day(day)),
              precision
            )
          )
        end

        private

        # The reading, rounded onto the nanosecond grid, so that reading its
        # civil fields gives a whole number of nanoseconds and any carry into
        # the next second or the next day has already happened.
        #
        # The grid is the day's own length, which the scale gives. On a leap
        # second day that is 86,401 seconds, so the seconds of the day are
        # rounded to whole nanoseconds against that, not against a fixed
        # 86,400. A day of the usual length lands on the same grid either way.
        #
        # The rounded value is held exactly, whatever the instant's precision,
        # because the reading is on its way to a String. Holding it as a
        # two-part float would round the clean grid value again, and near a
        # whole second that second rounding can push the last minute a
        # nanosecond the wrong way.
        #
        # @param reading [Horologium::ScaleReading] the reading to round
        # @return [Horologium::ScaleReading] the rounded reading, held exactly
        def nanosecond_reading(reading)
          scale = Horologium.configuration.scale(reading.scale)
          shifted = reading.value.to_r + HALF_DAY
          day = shifted.floor
          seclen = scale.seconds_in_day(day)

          seconds = (shifted - day) * seclen
          nanoseconds = (seconds * Duration::NANOSECONDS_PER_SECOND).round
          fraction = Rational(
            nanoseconds,
            seclen * Duration::NANOSECONDS_PER_SECOND
          )
          value = Numeric::Precision.build(day - HALF_DAY + fraction, :exact)

          ScaleReading.new(reading.scale, value, :exact)
        end

        # The date part of a civil time, the year written to at least four
        # digits and a sign only when the year is negative, so the string round
        # trips through the parser whatever the year.
        #
        # @param civil [Horologium::Representations::CivilTime] the civil time
        # @return [String] the date, as +YYYY-MM-DD+
        def date(civil)
          year =
            if civil.year.negative?
              format("-%04d", -civil.year)
            else
              format("%04d", civil.year)
            end

          format("%s-%02d-%02d", year, civil.month, civil.day)
        end

        # The fields an ISO 8601 string spells: a civil time, and the offset to
        # subtract from it to reach the scale, in seconds.
        #
        # @param value [String] the date and time
        # @return [Hash] the civil time under +:civil+ and the offset in
        #   seconds under +:offset_seconds+
        # @raise [ParseError] when the string is not in the subset it reads
        # @raise [ArgumentError] when the value is not a String
        def fields(value)
          unless value.is_a?(String)
            raise ArgumentError,
              "an ISO 8601 date and time is a String, got a #{value.class}"
          end

          match = PATTERN.match(value) || refuse(value)

          {
            civil: CivilTime.new(
              Integer(match[:year], 10),
              Integer(match[:month], 10),
              Integer(match[:day], 10),
              digits(match[:hour]),
              digits(match[:minute]),
              digits(match[:second]),
              fraction(match[:fraction])
            ),
            offset_seconds: offset_seconds(match[:zone])
          }
        end

        # 0 when the group was not there, so an omitted time of day is
        # midnight.
        #
        # @param group [String, nil]
        # @return [Integer]
        def digits(group)
          group.nil? ? 0 : Integer(group, 10)
        end

        # Exact, keeping every digit there is.
        #
        # @param group [String, nil] the digits after the decimal point
        # @return [Rational, Integer] the fraction, or 0 when there was none
        def fraction(group)
          return 0 if group.nil?

          Rational(group.to_i, 10**group.length)
        end

        # The offset a zone spells, in seconds, to subtract from the wall time
        # to reach the scale. +Z+ and no zone are a zero offset; +hh:mm+ ahead
        # of the scale is a positive offset, subtracted so the coordinate is
        # earlier, as ISO 8601 means it.
        #
        # @param zone [String, nil] +Z+, a numeric offset, or nil
        # @return [Integer] the offset, in seconds
        def offset_seconds(zone)
          return 0 if zone.nil? || zone == "Z"

          sign = (zone[0] == "-") ? -1 : 1
          hours = zone[1, 2].to_i
          minutes = zone[4, 2].to_i

          sign * (hours * 3_600 + minutes * 60)
        end

        # Refuses a string the parser does not read, naming the subset and
        # showing one it does.
        #
        # @param value [String] the string that was refused
        # @raise [ParseError] always
        def refuse(value)
          raise ParseError,
            "cannot read #{value.inspect} as an ISO 8601 date and time; it " \
            "is written as a date, and an optional time of day after a T, " \
            "such as \"2025-05-01T12:00:00.000000000\" or \"2025-05-01\""
        end
      end
    end
  end
end
