require 'i18nlite/backend/db'
require 'i18nlite/backend/simple_importer'

module I18nLite
  module Importer
    class SimpleBackend

      attr_accessor :target_locale, :source_locale, :translation_model, :locale_model

      def initialize(options)
        @translation_model = options.fetch(:translation_model)
        @locale_model   = options.fetch(:locale_model)
        @source_locale  = options.fetch(:source_locale)
        @target_locale  = options.fetch(:target_locale, I18n.system_locale)
      end

      def import!
        db_backend.store_translations(@target_locale, load_translations)
      end

      def sync!
        @translation_model.where(locale: @target_locale).destroy_all
        db_backend.store_translations(@target_locale, load_translations)
      end

      private

      def db_backend
        I18nLite::Backend::DB.new(
          translation_model: @translation_model,
          locale_model: @locale_model,
        )
      end

      def load_translations
        backend = I18nLite::Backend::SimpleImporter.new
        backend.all_flattened(@source_locale)
      end
    end
  end
end
