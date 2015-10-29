require 'i18nlite/backend/db'
require 'i18nlite/backend/simple_importer'

module I18nLite
  module Importer
    class SimpleBackend

      attr_accessor :target_locale, :source_locale, :model

      def initialize(model, source_locale, target_locale=I18n.system_locale)
        @model          = model
        @source_locale  = source_locale
        @target_locale  = target_locale
      end

      def import!
        db_backend = I18nLite::Backend::DB.new(@model)
        db_backend.store_translations(@target_locale, load_translations)
      end

      def sync!
        @model.where(locale: @target_locale).destroy_all

        db_backend = I18nLite::Backend::DB.new(@model)
        db_backend.store_translations(@target_locale, load_translations)
      end

      private

      def load_translations
        backend = I18nLite::Backend::SimpleImporter.new
        backend.all_flattened(@source_locale)
      end
    end
  end
end
