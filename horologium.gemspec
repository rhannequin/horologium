# frozen_string_literal: true

require_relative "lib/horologium/version"

Gem::Specification.new do |spec|
  spec.name = "horologium"
  spec.version = Horologium::VERSION
  spec.authors = ["Rémy Hannequin"]
  spec.email = ["remy.hannequin@gmail.com"]

  spec.summary = "Scientific time library for Ruby"
  spec.description = "Horologium is a Ruby library dedicated to scientific time: the time scales, high-precision instants, Julian Dates, intervals, and rigorous conversions between scales."
  spec.homepage = "https://github.com/rhannequin/horologium"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(
    %w[git ls-files -z],
    chdir: __dir__,
    err: IO::NULL
  ) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(
          *%w[
            bin/ Gemfile .gitignore test/ .github/ .rubocop.yml Steepfile
            sig-vendor/
          ]
        )
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "iers", "~> 0.2"

  spec.add_development_dependency "irb"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rbs", "~> 4.1.0"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-minitest"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "steep", "~> 2.0.0"
  spec.add_development_dependency "yard"
end
