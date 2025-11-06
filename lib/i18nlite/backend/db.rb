require 'i18nlite/backend/consistant_cache'
require 'i18nlite/backend/locale_meta'

module I18nLite
  module Backend
    # Database-backed I18n backend that stores translations in ActiveRecord models.
    #
    # Provides a complete I18n backend implementation using database storage with support
    # for locale fallbacks, pluralization, arrays, and metadata caching. Integrates with
    # ActiveRecord models for both translations and locale metadata.
    #
    # @example Basic setup
    #   backend = I18nLite::Backend::DB.new(
    #     translation_model: Translation,
    #     locale_model: Locale
    #   )
    #   I18n.backend = backend
    #
    # @see I18nLite::ActiveRecord::TranslationModel
    # @see I18nLite::ActiveRecord::LocaleModel
    class DB
      include I18n::Backend::Base
      include I18n::Backend::Flatten
      include I18nLite::Backend::ConsistentCache

      # ActiveRecord model for storing translations.
      #
      # @return [Class] model that includes I18nLite::ActiveRecord::TranslationModel
      attr_accessor :model

      # ActiveRecord model for storing locale metadata.
      #
      # @return [Class] model that includes I18nLite::ActiveRecord::LocaleModel
      attr_accessor :locale_model

      # Initializes the database backend with required models.
      #
      # @param options [Hash] configuration options
      # @option options [Class] :translation_model ActiveRecord model with TranslationModel concern
      # @option options [Class] :locale_model ActiveRecord model with LocaleModel concern
      # @raise [KeyError] if required options are missing
      def initialize(options)
        @model = options.fetch(:translation_model)
        @locale_model = options.fetch(:locale_model)
        super()
      end

      # Stores translations in the database for a given locale.
      #
      # Flattens nested translation data and persists it to the database. Arrays are stored
      # as individual entries with numeric suffixes (e.g., "key.0", "key.1", "key.2") plus
      # an additional entry with `is_array: true` to mark the base key as an array container.
      # During retrieval, array entries are reconstructed by sorting on the numeric suffix.
      #
      # @param locale [Symbol, String] the locale to store translations for
      # @param data [Hash] nested hash of translation keys and values
      # @param options [Hash] additional options (currently unused)
      # @return [Integer] number of translation records inserted or updated
      #
      # @example Storing simple translations
      #   store_translations(:en, { 'user.greeting' => 'Hello' })
      #
      # @example Storing array translations
      #   store_translations(:en, { 'days' => ['Mon', 'Tue', 'Wed'] })
      #   # Creates: days.0='Mon', days.1='Tue', days.2='Wed', days (is_array=true)
      #
      # @example Storing nested structures
      #   store_translations(:en, {
      #     user: { greeting: 'Hello', farewell: 'Goodbye' }
      #   })
      #   # Creates: user.greeting='Hello', user.farewell='Goodbye'
      def store_translations(locale, data, options = {})

        translations = []
        flatten_translations(nil, data, false, false).each_pair do |key, value|
          if value.kind_of?(Array)
            value.each_with_index do |t, i|
              translations.push({
                key: "#{key}.#{i}",
                locale: locale,
                translation: t
              })
            end
            translations.push({
              key: key,
              locale: locale,
              is_array: true
            })
          else
            translations.push({
              key: key,
              locale: locale,
              translation: value
            })
          end
        end

        @locale_model.insert_missing(locale)
        return @model.insert_or_update(translations)
      end

      # Returns all available locales from the database.
      #
      # @return [Array<Symbol>] array of locale codes as symbols
      def available_locales
        @locale_model.all_locales.map {|l| l.to_sym }
      end

      # Returns all translations as a flattened hash with locale fallback preference applied.
      #
      # @return [Hash{String => String}] flattened translation keys mapped to values
      # @example
      #   all_flattened
      #   #=> { "user.greeting" => "Hello", "user.farewell" => "Goodbye", "days.0" => "Monday" }
      # @see I18nLite::ActiveRecord::TranslationModel#all_by_preference_fast
      def all_flattened
        @model.all_by_preference_fast(locales)
      end

      # Returns all translations as an expanded nested hash structure.
      #
      # Retrieves all flattened translations and reconstructs them into a nested hash
      # where dot-separated keys become nested hash levels.
      #
      # @return [Hash] nested hash of translations
      #
      # @example
      #   all_expanded
      #   #=> { "user" => { "greeting" => "Hello", "farewell" => "Goodbye" } }
      def all_expanded
        flattened = @model.all_by_preference_fast(locales)
        expanded = {}

        flattened.each {|long_key, value|
          keys = long_key.to_s.split('.')
          i    = 0

          keys.reduce(expanded) {|hash_ref, key|
            hash_ref[key] = if (i += 1) == keys.size
              value
            else
              hash_ref[key] || {}
            end
          }
        }

        expanded
      end

      # Retrieves locale metadata from the database or cache.
      #
      # Returns a LocaleMeta object containing locale-specific properties such as text
      # direction, font preferences, or other custom attributes. Uses I18n.cache_store
      # when available for caching.
      #
      # @param locale [Symbol, String] the locale to retrieve metadata for
      # @return [I18nLite::Backend::LocaleMeta] locale metadata object (empty if locale not found)
      #
      # @example
      #   meta(:ar)
      #   #=> #<LocaleMeta {"locale"=>"ar", "rtl"=>true, "font"=>"Arial"}>
      def meta(locale)

        if I18n.cache_store
          I18n.cache_store.fetch( meta_cache_key(locale) ) do
            get_meta_from_db( locale )
          end
        else
          get_meta_from_db( locale )
        end
      end

    protected

      # Returns the locale fallback list or current locale.
      #
      # Uses I18n.fallback_list if available (an i18nlite extension), otherwise
      # falls back to the current locale only.
      #
      # @return [Array<Symbol>] ordered list of locales to try during lookup
      def locales
        I18n.fallback_list || [locale]
      end

      # Looks up a translation in the database with support for fallbacks, pluralization, and arrays.
      #
      # This method handles several special cases:
      # - Locale fallback: tries locales in preference order
      # - Pluralization: when :count option is present, searches for .one/.zero/.other variants
      # - Arrays: reconstructs arrays from indexed entries when base key has is_array=true
      #
      # @param locale [Symbol, String] the locale to lookup (fallback list applied automatically)
      # @param key [String, Symbol] the translation key
      # @param scope [Array, String, Symbol] optional scope prefix for the key
      # @param options [Hash] lookup options (e.g., :count for pluralization)
      # @return [String, Array, Hash, nil] the translation value, or nil if not found
      #
      # @note For pluralization, returns a Hash of pluralization forms when :count is provided
      #   but exact key match fails. For example: { one: "1 item", other: "%{count} items" }.
      #   The I18n pluralization engine processes this hash based on the :count value.
      def lookup(locale, key, scope = [], options = {})
        norm_key = self.normalize_flat_keys(locale, key, scope, nil)

        begin
          record = @model.by_preference!(norm_key, locales)
        rescue ::ActiveRecord::RecordNotFound
          if options.has_key?(:count)
            # If we didn't find a direct match, and :count was passed in, we'll
            # try to find matching '.one', '.zero' and pass them on to the magic
            # pluralization engine
            # If no match was found, we return nil, causing a missing translation exception

            result = Hash[
              @model.by_prefix_and_preference(norm_key, locales).map {
                |record|
                # Format the result for the pluralization engine
                [record.key.gsub(/^.+\./, '').to_sym, record.translation]
              }
            ]

            return result unless result.empty?
          end
          return nil
        end

        if record.is_array?
          as_array(@model.by_prefix(norm_key, record.locale).pluck(:key, :translation))
        else
          record.translation
        end
      end

    private

      # Fetches locale metadata from the database.
      #
      # @param locale [Symbol, String] the locale to fetch
      # @return [I18nLite::Backend::LocaleMeta] metadata object or empty object if not found
      def get_meta_from_db(locale)
        begin
          record = @locale_model.find_by!(locale: locale)
        rescue ::ActiveRecord::RecordNotFound
          return I18nLite::Backend::LocaleMeta.new
        end

        I18nLite::Backend::LocaleMeta.new.merge! record.attributes
      end

      # Reconstructs an array from indexed translation entries.
      #
      # Sorts entries by their numeric suffix and extracts values in order.
      #
      # @param elements [Array<Array(String, String)>] array of [key, translation] pairs
      # @return [Array<String>] ordered array of translation values
      def as_array(elements)
        elements.sort { |a, b|
          index_from_key(a[0]) <=> index_from_key(b[0])
        }.map { |e|
          e[1]
        }
      end

      # Extracts the numeric index from an array element key.
      #
      # @param key [String] key in format "base.key.0", "base.key.1", etc.
      # @return [Integer] the numeric index
      def index_from_key(key)
        key[key.rindex(".") + 1..-1].to_i
      end
    end
  end
end
