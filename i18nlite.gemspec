$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "i18nlite/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "i18nlite"
  s.version     = I18nLite::VERSION
  s.authors     = ["Avidity AB"]
  s.email       = ["code@avidity.se"]
  s.homepage    = "http://avidity.se"
  s.summary     = "Summary of I18nLite."
  s.description = "Description of I18nLite."

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~>4.1"
  s.add_dependency 'nokogiri', '1.6.7.2'
  s.add_dependency 'murmurhash3', '0.1.6'

  s.add_development_dependency 'pg', '0.17.1'
  s.add_development_dependency 'rspec-rails', '3.3'
  s.add_development_dependency 'database_cleaner', '1.1.1'
  s.add_development_dependency 'simplecov', '0.8.2'
end
