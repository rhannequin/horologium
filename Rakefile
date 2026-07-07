# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"
require "yard"

Minitest::TestTask.create
RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

desc "Type check with Steep"
task :steep do
  sh "steep check"
end

desc "Verify YARD documentation coverage is 100%"
task :yard_coverage do
  require "open3"
  output, status = Open3.capture2e("yard", "stats", "--list-undoc")
  puts output
  unless status.success? && output.include?("100.00% documented")
    abort "YARD documentation coverage is below 100%"
  end
end

task default: %i[test rubocop]
