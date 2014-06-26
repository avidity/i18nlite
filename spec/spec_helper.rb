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


# https://gist.github.com/Fivell/8025849
RSpec::Matchers.define :have_xml do |xpath, text|
  match do |body|
    doc = Nokogiri::XML::Document.parse(body)
    nodes = doc.xpath(xpath)
    expect(nodes.empty?).to be false
    if text
      nodes.each do |node|
        expect(node.content).to eq text
      end
    end
    true
  end

  failure_message_for_should do |body|
    "expected to find xml tag #{xpath} in:\n#{body}"
  end

  failure_message_for_should_not do |body|
    "expected not to find xml tag #{xpath} in:\n#{body}"
  end

  description do
    "have xml tag #{xpath}"
  end
end
