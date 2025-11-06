require 'i18nlite/backend/db'
require 'i18nlite/backend/simple_importer'

module I18nLite
  module Importer
    # Imports translations from I18n Simple backend (YAML/Ruby files) to database.
    #
    # This importer reads translations from the standard I18n Simple backend (typically
    # loaded from YAML or Ruby files) and stores them in the database using the DB backend.
    # It supports both incremental imports and full synchronization.
    #
    # The importer is useful for:
    # - Initial migration from file-based translations to database storage
    # - Synchronizing translations from version-controlled YAML files to the database
    # - Bulk loading translations during deployment or setup
    #
    # @example Basic import from YAML files
    #   # Assuming YAML files are already loaded by I18n
    #   importer = I18nLite::Importer::SimpleBackend.new(
    #     translation_model: Translation,
    #     locale_model: Locale,
    #     source_locale: :en,
    #     target_locale: :en
    #   )
    #   importer.import!
    #
    # @example Sync all Swedish translations (destructive)
    #   importer = I18nLite::Importer::SimpleBackend.new(
    #     translation_model: Translation,
    #     locale_model: Locale,
    #     source_locale: :sv,
    #     target_locale: :sv
    #   )
    #   importer.sync!  # Removes existing :sv translations, then imports
    #
    # @example Import from multiple locales
    #   [:en, :sv, :no, :da].each do |locale|
    #     importer = I18nLite::Importer::SimpleBackend.new(
    #       translation_model: Translation,
    #       locale_model: Locale,
    #       source_locale: locale,
    #       target_locale: locale
    #     )
    #     importer.import!
    #   end
    #
    # @see I18nLite::Backend::DB
    # @see I18nLite::Backend::SimpleImporter
    class SimpleBackend

      # The target locale to import translations into in the database.
      #
      # @return [Symbol] locale code
      attr_accessor :target_locale

      # The source locale to read translations from in the Simple backend.
      #
      # @return [Symbol] locale code
      attr_accessor :source_locale

      # The ActiveRecord model for storing translations.
      #
      # @return [Class] ActiveRecord model class (must include TranslationModel)
      attr_accessor :translation_model

      # The ActiveRecord model for storing locale metadata.
      #
      # @return [Class] ActiveRecord model class (must include LocaleModel)
      attr_accessor :locale_model

      # Initializes a new Simple backend importer.
      #
      # @param options [Hash] configuration options
      # @option options [Class] :translation_model (required) ActiveRecord model for translations
      # @option options [Class] :locale_model (required) ActiveRecord model for locale metadata
      # @option options [Symbol, String] :source_locale (required) locale to read from Simple backend
      # @option options [Symbol, String] :target_locale locale to write to database (defaults to I18n.system_locale)
      #
      # @raise [KeyError] if required options are missing
      #
      # @example Standard initialization
      #   importer = I18nLite::Importer::SimpleBackend.new(
      #     translation_model: Translation,
      #     locale_model: Locale,
      #     source_locale: :en,
      #     target_locale: :en
      #   )
      def initialize(options)
        @translation_model = options.fetch(:translation_model)
        @locale_model   = options.fetch(:locale_model)
        @source_locale  = options.fetch(:source_locale)
        @target_locale  = options.fetch(:target_locale, I18n.system_locale)
      end

      # Imports translations from Simple backend to database.
      #
      # Loads all flattened translations for the source locale from the I18n Simple
      # backend and stores them in the database. This is an incremental operation that
      # updates existing translations and inserts new ones. Existing translations in
      # the database that are not present in the source are left unchanged.
      #
      # @return [void]
      #
      # @example Import English translations
      #   importer.import!
      #   # Existing database translations are updated
      #   # New translations from YAML files are inserted
      #   # Database translations not in YAML files are preserved
      #
      # @see #sync!
      def import!
        db_backend.store_translations(@target_locale, load_translations)
      end

      # Synchronizes database translations with Simple backend (destructive).
      #
      # Completely replaces all database translations for the target locale with
      # translations from the Simple backend. This is a destructive operation that:
      # 1. Deletes ALL existing translations for the target locale from the database
      # 2. Imports all translations from the Simple backend
      #
      # Use this method when you want the database to exactly match the file-based
      # translations, removing any database-only translations.
      #
      # @return [void]
      #
      # @example Sync to match YAML files exactly
      #   importer.sync!
      #   # All existing :sv translations are deleted
      #   # All :sv translations from YAML files are imported
      #
      # @example Comparison with import!
      #   # Database has: { "greeting" => "Hej", "old_key" => "Gammal" }
      #   # YAML has: { "greeting" => "Hallå", "farewell" => "Hejdå" }
      #
      #   importer.import!
      #   # Result: { "greeting" => "Hallå", "old_key" => "Gammal", "farewell" => "Hejdå" }
      #
      #   importer.sync!
      #   # Result: { "greeting" => "Hallå", "farewell" => "Hejdå" }
      #
      # @note This operation permanently deletes translations and cannot be undone.
      # @see #import!
      def sync!
        @translation_model.where(locale: @target_locale).destroy_all
        db_backend.store_translations(@target_locale, load_translations)
      end

      private

      # Creates a DB backend instance for storing translations.
      #
      # @return [I18nLite::Backend::DB] configured DB backend
      # @api private
      def db_backend
        I18nLite::Backend::DB.new(
          translation_model: @translation_model,
          locale_model: @locale_model,
        )
      end

      # Loads flattened translations from the Simple backend.
      #
      # Uses the SimpleImporter backend to read all translations for the source
      # locale from I18n's current backend (typically Simple backend with YAML files).
      # Returns translations as a flattened hash suitable for database storage.
      #
      # @return [Hash] flattened translations hash (e.g., { "user.greeting" => "Hello" })
      # @api private
      def load_translations
        backend = I18nLite::Backend::SimpleImporter.new
        backend.all_flattened(@source_locale)
      end
    end
  end
end
