# frozen_string_literal: true

require_relative "horologium/error"
require_relative "horologium/numeric/exact"
require_relative "horologium/numeric/two_part_float"
require_relative "horologium/numeric/precision"
require_relative "horologium/precise_value"
require_relative "horologium/duration"
require_relative "horologium/scales/base"
require_relative "horologium/scales/tai"
require_relative "horologium/scales/tt"
require_relative "horologium/data/barycentric_model"
require_relative "horologium/scales/tdb"
require_relative "horologium/data/leap_seconds"
require_relative "horologium/scales/utc"
require_relative "horologium/configuration"
require_relative "horologium/representations/julian_date"
require_relative "horologium/representations/modified_julian_date"
require_relative "horologium/representations/civil_time"
require_relative "horologium/representations/civil"
require_relative "horologium/representations/iso8601"
require_relative "horologium/scale_reading"
require_relative "horologium/instant"
require_relative "horologium/version"

# Horologium is a Ruby library dedicated to scientific time: the time scales,
# high-precision instants, Julian Dates, intervals, and rigorous conversions
# between scales.
module Horologium
end
