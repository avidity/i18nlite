$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "i18nlite/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "i18nlite"
  s.version     = I18nLite::VERSION
  s.authors     = ["Promote International AB"]
  s.email       = ["code@promoteint.com"]
  s.homepage    = "https://promoteint.com"
  s.summary     = "I18n framework for Rails"
  s.description = "I18n backend with support for locale inheritance"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ['>= 4.2.11.1', '<= 5.2.3']
  s.add_dependency 'nokogiri', '~> 1.8'
  s.add_dependency 'murmurhash3', '0.1.6'

  s.add_development_dependency 'pg', '0.18.4'
  s.add_development_dependency 'rspec-rails', '3.7'
  s.add_development_dependency 'database_cleaner', '1.7.0'
  s.add_development_dependency 'simplecov', '0.8.2'
  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'bump', '~> 0.6'
end
