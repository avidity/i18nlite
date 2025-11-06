module I18nLite
  module ActiveRecord
    # ActiveRecord concern providing locale management functionality.
    #
    # This module extends ActiveRecord models with methods to manage locale records
    # in the database. It provides functionality to retrieve all available locales
    # and ensure specific locales exist in the database (creating them if missing).
    # Typically used in conjunction with I18nLite::Backend::DB to manage available
    # locales for translations.
    #
    # @example Including in an ActiveRecord model
    #   class Locale < ActiveRecord::Base
    #     include I18nLite::ActiveRecord::LocaleModel
    #   end
    #
    # @example Creating and querying locales
    #   # Insert locales that don't already exist
    #   Locale.insert_missing(:en, :sv, :ar)
    #
    #   # Retrieve all locale codes
    #   Locale.all_locales  #=> ["ar", "en", "sv"]
    #
    # @example Setting up with I18nLite backend
    #   backend = I18nLite::Backend::DB.new(
    #     translation_model: Translation,
    #     locale_model: Locale
    #   )
    #   I18n.backend = backend
    #
    # @see I18nLite::Backend::DB
    # @see I18nLite::Backend::LocaleMeta
    module LocaleModel
      def self.included(model)
        model.extend ClassMethods
      end

      module ClassMethods
        # Retrieves all locale codes from the database.
        #
        # Returns an ordered array of locale codes (strings) from the `locale`
        # column. Results are sorted alphabetically by locale code. This method
        # is optimized to fetch only the locale column rather than full records.
        #
        # @return [Array<String>] sorted array of locale codes
        #
        # @example Retrieving all locales
        #   Locale.all_locales  #=> ["ar", "en", "sv"]
        #
        # @example Empty database
        #   Locale.all_locales  #=> []
        def all_locales
          self.select(:locale)
              .order(:locale)
              .pluck(:locale)
        end

        # Inserts locale records for locales that don't already exist.
        #
        # Creates database records for the specified locales, but only if they
        # don't already exist. Existing locales are silently ignored, making this
        # operation idempotent and safe to call multiple times with the same values.
        # Accepts locale codes as either strings or symbols.
        #
        # @param locales [Array<String, Symbol>] one or more locale codes to ensure exist
        # @return [Array<ActiveRecord::Base>, nil] array of newly created records, or nil if no records were created
        #
        # @example Inserting new locales
        #   Locale.insert_missing(:en, :sv)
        #   Locale.all_locales  #=> ["en", "sv"]
        #
        # @example Idempotent operation
        #   Locale.insert_missing(:en)  # Creates 'en'
        #   Locale.insert_missing(:en)  # Does nothing, 'en' already exists
        #
        # @example Mixed new and existing locales
        #   Locale.insert_missing(:en)        # Creates 'en'
        #   Locale.insert_missing(:en, :sv)   # Creates only 'sv', ignores 'en'
        #   Locale.all_locales  #=> ["en", "sv"]
        #
        # @note This method accepts symbols but stores them as strings in the database
        def insert_missing(*locales)
          existing = all_locales
          spec = locales.delete_if { |l| existing.include? l.to_s }
                        .map { |l| { locale: l } }
          self.create(spec) unless spec.empty?
        end
      end
    end
  end
end
