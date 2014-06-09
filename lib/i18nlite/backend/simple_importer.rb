module I18nLite
  module Backend
    class SimpleImporter < I18n::Backend::Simple
      include I18n::Backend::Flatten

      def all_flattened(locale=I18n.locale)
        init_translations
        flatten_translations(nil, translations[locale], false, nil)
      end
    end
  end
end
