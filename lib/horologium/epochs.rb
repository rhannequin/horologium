# frozen_string_literal: true

module Horologium
  # The astronomical epochs, built as instants. An epoch is an ordinary
  # {Instant}. The elapsed time since one is a subtraction, and no Julian Date
  # is involved.
  module Epochs
    # 2000-01-01 12:00:00 TT, Julian Date 2451545.0 in TT. The epoch the
    # current theories of the solar system motion are written for.
    J2000 = Instant.from_tt(2000, 1, 1, 12, precision: :exact)

    # 1899-12-31 12:00:00 TT, Julian Date 2415020.0 in TT. It is one Julian
    # century of 36,525 days before {J2000}, and it is what the older formulae
    # count from. The date is a day earlier than the name suggests.
    J1900 = Instant.from_tt(1899, 12, 31, 12, precision: :exact)

    # 1980-01-06 00:00:00 UTC, where GPS time starts. TAI - UTC was 19 seconds
    # on that day. GPS time counts SI seconds from here. It stays a fixed
    # offset from TAI.
    GPS_ZERO = Instant.from_tai(1980, 1, 6, 0, 0, 19, precision: :exact)

    # 1970-01-01 00:00:00 UTC, where Unix time starts. UTC was still steered
    # by rate adjustments in 1970, so TAI - UTC was 8.000082 seconds on that
    # day.
    UNIX = Instant.from_tai(
      1970, 1, 1, 0, 0,
      Rational(8_000_082, 1_000_000),
      precision: :exact
    )

    # 1977-01-01 00:00:00 TAI, Julian Date 2443144.5003725 in TT. TT, TCG and
    # TCB were set to read the same here, and the rates that separate them are
    # counted from this point.
    TT_TCG_TCB_ORIGIN = Instant.from_tai(1977, 1, 1, precision: :exact)
  end
end
