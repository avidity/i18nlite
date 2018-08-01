require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :database => ENV.fetch('I18NLITE_DB_NAME', 'i18nlite_test'),
  :email => ENV.fetch('I18NLITE_DB_USER', 'i18nlite_test'),
  :password => ENV.fetch('I18NLITE_DB_PASS', 'i18nlite_test')
)

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :test_translations, :force => true do |t|
    t.string :key
    t.string :locale
    t.string :translation
    t.boolean :is_array
    t.timestamps
  end

  create_table :test_locales, :force => true do |t|
    t.string :locale
    t.string :font
    t.string :name
    t.boolean :rtl, default: false
  end
end

class TestLocale < ActiveRecord::Base
  include I18nLite::ActiveRecord::LocaleModel
end

class TestTranslation < ActiveRecord::Base
  include I18nLite::ActiveRecord::TranslationModel
end
