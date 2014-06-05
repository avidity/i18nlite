# This file is copied to spec/ when you run 'rails generate rspec:install'
#ENV["RAILS_ENV"] ||= 'test'
#require File.expand_path("../dummy/config/environment", __FILE__)

$: << File.join(File.dirname(__FILE__), '../lib')

require 'i18nlite'
require 'rspec/autorun'
require 'active_record_helper'
require 'database_cleaner'

if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start 'rails'
end


RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)

  end

  config.before(:each) do
    DatabaseCleaner.start
    I18n.stub(:enforce_available_locales).and_return(false)
    I18n.stub(:enforce_available_locales!)
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.order = "random"
end
