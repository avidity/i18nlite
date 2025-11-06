require 'murmurhash3'

module I18nLite
  module Backend
    # Provides consistent cache key generation for I18n translation lookups.
    #
    # This module extends I18n::Backend::Cache with custom cache key generation
    # that produces stable, predictable keys for translation caching. Only option
    # values (not keys) are hashed to generate shorter cache keys while maintaining
    # uniqueness.
    module ConsistentCache
      include I18n::Backend::Cache

      # Generates a cache key for translation lookups.
      #
      # Uses fallback list if available, otherwise single locale. Only option values
      # (not keys) are hashed using MurmurHash3 to produce shorter cache keys.
      #
      # @param locale [Symbol, String] the locale for the translation
      # @param key [String, Symbol] the translation key
      # @param options [Hash] additional options passed to the translation lookup
      # @return [String] a cache key in the format "i18n/;locale_key;/key/hash"
      #   where hash is a MurmurHash3 of option values, or empty when no options
      # @note The trailing "/" when options are empty is intentional to provide
      #   consistent structure for simpler consumer code
      #
      # @example With no options
      #   cache_key(:en, 'user.greeting', {})
      #   #=> "i18n/;en;/user.greeting/"
      #
      # @example With fallback locales
      #   cache_key(:sv, 'user.greeting', {name: "John"})
      #   #=> "i18n/;sv;en;system;/user.greeting/1234567890"
      def cache_key(locale, key, options)
        locale_key = if I18n.respond_to? :fallback_list
          I18n.fallback_list(locale).join(';')
        else
          locale
        end

        hash = (options.empty?) ? '' : MurmurHash3::V32.str_hash(options.values.join(';'))
        "i18n/;#{locale_key};/#{key}/#{hash}"
      end

      # Generates a cache key for locale metadata.
      #
      # @param locale [Symbol, String] the locale
      # @return [String] a cache key in the format "i18n/meta/locale"
      def meta_cache_key(locale)
        "i18n/meta/#{locale}"
      end
    end
  end
end
