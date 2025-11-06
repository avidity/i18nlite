module I18nLite
  module Backend
    # I18n backend for importing translations from YAML files with flattening support.
    #
    # Extends the standard Simple backend with translation flattening capabilities
    # and restricts file loading to YAML files only (Ruby files are not supported).
    # Used primarily for importing translations into a database backend.
    #
    # @example Using the importer
    #   importer = I18nLite::Backend::SimpleImporter.new
    #   importer.load_translations('config/locales/en.yml')
    #   translations = importer.all_flattened(:en)
    #   #=> { "user.greeting" => "Hello", "user.farewell" => "Goodbye" }
    class SimpleImporter < I18n::Backend::Simple
      include I18n::Backend::Flatten

      # Returns all translations for a locale as a flattened hash.
      #
      # Converts nested translation structures into dot-separated keys.
      #
      # @param locale [Symbol, String] the locale to flatten (defaults to current locale)
      # @return [Hash{String => String}] flattened translation keys mapped to values
      #
      # @example
      #   all_flattened(:en)
      #   #=> { "user.greeting" => "Hello", "user.farewell" => "Goodbye" }
      def all_flattened(locale = I18n.locale)
        init_translations
        flatten_translations(nil, translations[locale], false, nil)
      end

      # Loads translation files, restricted to YAML format only.
      #
      # Overrides the default Simple backend behavior to prevent loading Ruby files,
      # as dynamic content evaluation is not supported.
      #
      # @param filenames [Array<String>] paths to translation files (uses I18n.load_path if empty)
      # @return [void]
      #
      # @note Only .yml and .yaml files are loaded; .rb files are ignored
      def load_translations(*filenames)
        filenames = I18n.load_path if filenames.empty?
        filenames = filenames.flatten.select { |filename| filename.end_with?('yml', 'yaml') }
        filenames.each { |filename| load_file(filename) }
      end
    end
  end
end
