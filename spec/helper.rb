require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'simplecov'
require 'coveralls'
Coveralls.wear!

SimpleCov.formatters = [
  Coveralls::SimpleCov::Formatter,
  SimpleCov::Formatter::HTMLFormatter
]

SimpleCov.start do
  add_filter 'spec/support'
end

require 'rspec'
require 'rspec/its'
require 'rspec/collection_matchers'
require 'pp' # avoids conflict with fakefs: https://github.com/fakefs/fakefs/issues/99
require 'fakefs/spec_helpers'

Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each{ |f| require f }

RSpec.configure do |config|
  config.include FakeFS::SpecHelpers, fakefs: true
end

require 'probedock-ruby'
