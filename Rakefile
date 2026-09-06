# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"
require "yard"

Minitest::TestTask.create do |t|
  t.framework = %(require "test_helper")
end

RuboCop::RakeTask.new
YARD::Rake::YardocTask.new

desc "Type check with Steep"
task :steep do
  sh "steep check"
end

desc "Verify YARD documentation coverage is 100% and parses without warning"
task :yard_coverage do
  require "open3"
  output, status = Open3.capture2e("yard", "stats", "--list-undoc")
  puts output
  unless status.success? && output.include?("100.00% documented")
    abort "YARD documentation coverage is below 100%"
  end

  # Coverage counts a comment block, not the method it belongs to, so a block
  # that landed above the wrong method still reads as documented while the
  # method it was written for reads as documented too. The warnings are what
  # notice: a @param naming a parameter the method does not have is a block
  # that has come adrift.
  warnings, = Open3.capture2e("yard", "--no-output")
  lines = warnings.lines.grep(/\[warn\]/)
  next if lines.empty?

  puts lines
  abort "YARD parsed #{lines.length} warning(s)"
end

task default: %i[test rubocop]
