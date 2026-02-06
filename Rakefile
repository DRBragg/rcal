# frozen_string_literal: true

require "rake/testtask"
require "standard/rake"

#
# Test tasks
#
desc "Run all tests"
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Run unit tests only"
Rake::TestTask.new("test:unit") do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/unit/**/*_test.rb"]
end

desc "Run integration tests only"
Rake::TestTask.new("test:integration") do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/integration/**/*_test.rb"]
end

#
# Lint tasks
#
desc "Run StandardRB linter"
task :lint do
  sh "bundle exec standardrb"
end

desc "Run StandardRB linter and auto-fix"
task "lint:fix" do
  sh "bundle exec standardrb --fix"
end

#
# Default task
#
desc "Run tests and linter"
task default: [:test, :lint]
