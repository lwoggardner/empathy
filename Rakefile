require "bundler/gem_tasks"

require 'rspec/core'
require 'rspec/core/rake_task'
require 'rdoc/task'
require 'rake/clean'

RSpec::Core::RakeTask.new(:spec)

RDoc::Task.new do |rdoc|
    rdoc.main = "README.rdoc"
    rdoc.rdoc_files.include("README.rdoc", "CHANGELOG","lib/**/*.rb")
    rdoc.title = "Empathy"
end

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
CLOBBER.include [ "pkg/" ]

