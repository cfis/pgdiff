#!/usr/bin/env ruby

require 'rubygems'
require 'rubygems/package_task'
require 'rake/testtask'

GEM_NAME = 'pgdiff'

# Read the spec file
spec = Gem::Specification.load("#{GEM_NAME}.gemspec")

# Setup generic gem
Gem::PackageTask.new(spec) do |pkg|
  pkg.package_dir = 'pkg'
  pkg.need_tar    = false
end

Rake::TestTask.new do |task|
  task.libs << "test"
  task.test_files = FileList['test/test*.rb']
  task.verbose = true
end

# Add task to create test database
load 'test/fixtures/database.rake'
