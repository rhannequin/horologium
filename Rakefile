# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Type check with Steep"
task :steep do
  sh "steep check"
end

task default: %i[test rubocop]
