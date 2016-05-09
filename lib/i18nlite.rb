require 'i18n'
require 'rails'

Dir[File.dirname(__FILE__) + '/i18nlite/**/*.rb'].each do
  |file|
  require file
end

module I18nLite
  module Rails
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'i18nlite/tasks/i18nlite.rake'
      end
    end
  end
end
