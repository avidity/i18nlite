require 'i18n'

Dir[File.dirname(__FILE__) + '/i18nlite/**/*.rb'].each do
  |file|
  require file
end

module I18nLite
end
