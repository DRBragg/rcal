# frozen_string_literal: true

require_relative "lib/rcal/version"

Gem::Specification.new do |spec|
  spec.name = "r_cal"
  spec.version = Rcal::VERSION
  spec.authors = ["Drew Bragg"]
  spec.email = ["drbragg@gmail.com"]

  spec.summary = "A fast, pure Ruby command-line interface for Google Calendar"
  spec.description = "r_cal is a fast CLI tool for Google Calendar with natural language date parsing, " \
                     "event management, ICS import, and predicate filtering. Built with cli-kit for snappy performance."
  spec.homepage = "https://github.com/DRBragg/rcal"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/DRBragg/rcal"
  spec.metadata["changelog_uri"] = "https://github.com/DRBragg/rcal/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "cli-kit", "~> 5.2.0"
  spec.add_dependency "cli-ui", "~> 2.7.0"

  # Ruby 4.0 requires these to be explicit
  spec.add_dependency "pstore"
  spec.add_dependency "readline"
  spec.add_dependency "reline"

  # Google Calendar API
  spec.add_dependency "google-apis-calendar_v3", "~> 0.30"
  spec.add_dependency "googleauth", "~> 1.8"

  # Open URLs in browser
  spec.add_dependency "launchy", ">= 2.4", "< 4.0"

  # Date/time parsing
  spec.add_dependency "chronic", "~> 0.10"
  spec.add_dependency "chronic_duration", "~> 0.10"

  # ICS parsing
  spec.add_dependency "icalendar", "~> 2.10"

  # Development dependencies
  spec.add_development_dependency "rake"
  spec.add_development_dependency "standard"

  # Test dependencies
  spec.add_development_dependency "mocha", "~> 2.1"
  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "minitest-reporters"
  spec.add_development_dependency "timecop", "~> 0.9"
end
