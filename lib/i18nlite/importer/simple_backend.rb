
module I18nLite
  module Importer
    class SimpleBackend
      def initialize(model, source_locale, target_locale=I18n.system_locale)
        @database_model = model
        @source_locale  = source_locale
        @target_locale  = target_locale
      end

      def import!
        db_backend = I18nLite::Backend::DB.new(@database_model)
        db_backend.store_translations(@target_locale, load_translations)
      end

      def sync!
        @database_model.where(locale: @target_locale).destroy_all

        db_backend = I18nLite::Backend::DB.new(@database_model)
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
