# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    enable_coverage :branch
    minimum_coverage line: 100, branch: 100
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "horologium"

require "minitest/autorun"
