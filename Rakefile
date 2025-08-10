# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

# Load dotenv for tests
begin
  require "dotenv/load"
rescue LoadError
  # dotenv not available, skip loading
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

task default: :test

desc "Run RuboCop"
task :rubocop do
  sh "rubocop"
end

desc "Run tests and linting"
task ci: [:test, :rubocop]

desc "Generate documentation"
task :doc do
  sh "yard doc"
end

desc "Open console with gem loaded"
task :console do
  sh "bundle console"
end