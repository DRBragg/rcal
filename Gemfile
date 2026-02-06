source "https://rubygems.org"

gem "cli-kit", "~> 5.2.0"
gem "cli-ui", "~> 2.7.0"

# Ruby 4.0 requires these to be explicit
gem "pstore"
gem "readline"
gem "reline"

# Google Calendar API
gem "google-apis-calendar_v3", "~> 0.30"
gem "googleauth", "~> 1.8"

# Open URLs in browser
gem "launchy", "~> 2.4"

# Date/time parsing
gem "chronic", "~> 0.10"
gem "chronic_duration", "~> 0.10"

# ICS parsing
gem "icalendar", "~> 2.10"

group :development do
  gem "rake", require: false
  gem "standard", require: false
end

group :test do
  gem "mocha", "~> 2.1", require: false
  gem "minitest", "~> 5.20", require: false
  gem "minitest-reporters", require: false
  gem "timecop", "~> 0.9", require: false
end
