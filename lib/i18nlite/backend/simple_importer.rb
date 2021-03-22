module I18nLite
  module Backend
    class SimpleImporter < I18n::Backend::Simple
      include I18n::Backend::Flatten

      def all_flattened(locale = I18n.locale)
        init_translations
        flatten_translations(nil, translations[locale], false, nil)
      end

      # FIXME: Overrides default function, because we have to prevent rb files from being loaded
      # since we can't insert dynamic content yet
      def load_translations(*filenames)
        filenames = I18n.load_path if filenames.empty?
        filenames = filenames.flatten.select { |filename| filename.end_with?('yml', 'yaml') }
        filenames.each { |filename| load_file(filename) }
      end
    end
  end
end
