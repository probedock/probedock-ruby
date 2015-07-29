# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "probedock-ruby"
  gem.homepage = "https://github.com/probedock/probedock-ruby"
  gem.license = "MIT"
  gem.summary = %Q{Ruby library to develop new probes for Probe Dock.}
  gem.description = %Q{Ruby library to develop new probes for Probe Dock. It can parse Probe Dock configuration files, collect test results and publish them to a Probe Dock server.}
  gem.email = "devops@probedock.io"
  gem.authors = ["Simon Oulevay (Alpha Hydrae)"]
  gem.files = Dir["lib/**/*.rb"] + %w(Gemfile LICENSE.txt README.md VERSION)
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

# version tasks
require 'rake-version'
RakeVersion::Tasks.new do |v|
  v.copy 'README.md'
  v.copy 'lib/probe_dock_ruby.rb'
end

require 'rspec/core/rake_task'
desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  #t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  # Put spec opts in a file named .rspec in root
end

task default: :spec
