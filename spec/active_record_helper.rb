require 'active_record'

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => ENV.fetch('I18NLITE_DB_HOST', ''),
  :database => ENV.fetch('I18NLITE_DB_NAME', 'i18nlite_test'),
  :username => ENV.fetch('I18NLITE_DB_USER', ''),
  :password => ENV.fetch('I18NLITE_DB_PASS', '')
)

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :test_translations, :force => true do |t|
    t.string :key
    t.string :locale
    t.string :translation
    t.boolean :is_array
    t.timestamps null: false
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
