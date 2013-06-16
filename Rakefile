require "bundler/gem_tasks"

require 'rspec/core'
require 'rspec/core/rake_task'
require 'yard'
require 'rake/clean'

RSpec::Core::RakeTask.new(:spec)

YARD::Rake::YardocTask.new

# Create the test task.
desc 'Run mspec'
task :mspec do
  sh "mspec -B empathy.mspec -r 'mspec/empathy' -f spec"
end

# Run specs against ruby
desc "Run tests on native ruby"
task :mspec_ruby do
  sh "mspec -B empathy.mspec"
end

desc "Run tests"
task :test => [ :spec, :mspec ]

task :default => [ :test, :build ]

CLOBBER.include [ "pkg/","doc/" ]

