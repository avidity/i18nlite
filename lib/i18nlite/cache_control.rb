module I18nLite
  # Provides cache control functionality for I18n translations.
  #
  # This module handles selective and bulk clearing of cached translation data,
  # adapting to different cache store implementations (Redis, Memory, File stores).
  # It automatically selects the appropriate cache adaptor based on the configured
  # I18n cache store.
  #
  # @example Clear specific translation keys
  #   I18nLite::CacheControl.clear_keys(:'my.string', :'my_other_string')
  #
  # @example Clear all translations for a locale
  #   I18nLite::CacheControl.clear_locale(:en)
  #
  # @example Clear all cached translations
  #   I18nLite::CacheControl.clear_all
  #
  # @example Check if keyed clearing is supported
  #   I18nLite::CacheControl.can_clear_keys? # => true or false
  #
  # @example Access the cache adaptor directly
  #   I18nLite::CacheControl.adaptor # => instance of KeyedCacheAdaptor
  module CacheControl

    class << self
      # Clears cached translations for specific translation keys.
      #
      # Removes all cached entries matching the provided translation keys across
      # all locales. Falls back to clearing the entire cache if the cache store
      # doesn't support pattern-based deletion.
      #
      # @param keys [Array<String, Symbol>] translation keys to clear from cache
      # @return [void]
      #
      # @example Clear multiple keys
      #   clear_keys(:user_greeting, :user_farewell, :'errors.not_found')
      def clear_keys(*keys)
        begin
          keys.each do |key|
            I18n.cache_store.delete_matched( adaptor.scoped_pattern(key) )
          end
        rescue NotImplementedError
          I18n.cache_store.clear
        end
      end

      # Clears all cached translations for a specific locale.
      #
      # Removes all cached translation entries for the given locale, regardless
      # of translation key. Falls back to clearing the entire cache if the cache
      # store doesn't support pattern-based deletion.
      #
      # @param locale [String, Symbol] the locale to clear (e.g., :en, :de, :fr)
      # @return [void]
      #
      # @example Clear all English translations
      #   clear_locale(:en)
      def clear_locale(locale)
        begin
          I18n.cache_store.delete_matched( adaptor.locale_pattern(locale) )
        rescue NotImplementedError
          I18n.cache_store.clear
        end
      end

      # Clears all I18n cached translations.
      #
      # Removes all cached translation entries for all locales and keys. This uses
      # a greedy pattern to match all I18n cache entries. Falls back to clearing
      # the entire cache if the cache store doesn't support pattern-based deletion.
      #
      # @return [void]
      #
      # @example Clear all cached translations
      #   clear_all
      def clear_all
        begin
          I18n.cache_store.delete_matched( adaptor.greedy_pattern )
        rescue NotImplementedError
          I18n.cache_store.clear
        end
      end

      # Checks whether the current cache store supports keyed cache clearing.
      #
      # Returns true if the configured cache adaptor can generate patterns for
      # selective cache deletion. If false, all clear operations will fall back
      # to clearing the entire cache.
      #
      # @return [Boolean] true if keyed clearing is supported, false otherwise
      #
      # @example Check support before clearing specific keys
      #   if can_clear_keys?
      #     clear_keys(:specific_key)
      #   else
      #     clear_all
      #   end
      def can_clear_keys?
        adaptor.greedy_pattern.present?
      end

      # Returns the cache adaptor for the configured I18n cache store.
      #
      # Automatically selects and instantiates the appropriate adaptor based on
      # the type of cache store configured in I18n. Supports Redis, Memory, and
      # File stores through specialized adaptors.
      #
      # @return [KeyedCacheAdaptor::Base] the cache adaptor instance
      #
      # @example Get the current adaptor
      #   adaptor.class # => I18nLite::KeyedCacheAdaptor::Redis
      def adaptor
        KeyedCacheAdaptor::Base.adaptor_for( I18n.cache_store )
      end
    end
  end

  # Adaptor pattern for cache store-specific cache key pattern generation.
  #
  # This module provides adaptors that generate cache key patterns appropriate
  # for different cache store implementations. Each adaptor knows how to create
  # patterns for selective cache deletion based on the cache store's capabilities.
  module KeyedCacheAdaptor
    # Base adaptor class that provides the factory method for adaptor selection.
    #
    # Subclasses should implement pattern methods and declare which cache stores
    # they handle via the {.handles} class method.
    class Base
      # Factory method that returns the appropriate adaptor for a cache store.
      #
      # Selects an adaptor by checking each subclass to see if it handles the
      # given store type. Results are memoized per store class. Falls back to
      # the base adaptor if no specific adaptor is found.
      #
      # @param store [Object] the I18n cache store instance
      # @return [Base] an adaptor instance appropriate for the store
      #
      # @example Get adaptor for Redis store
      #   store = ActiveSupport::Cache::RedisStore.new
      #   adaptor = Base.adaptor_for(store)
      #   adaptor.class # => I18nLite::KeyedCacheAdaptor::Redis
      def self.adaptor_for(store)
        @@adaptors ||= {}
        @@adaptors[store.class.to_s.to_sym] ||= (self.subclasses.find do
          |subclass|
          subclass.handles.any? do
            |supported_store|
            begin
              store.instance_of?(supported_store.constantize)
            rescue NameError
              false
            end
          end
        end || self).new
      end

      # Generates a pattern to match all cache keys for a specific locale.
      #
      # @param key [String, Symbol] the locale identifier
      # @return [String, nil] pattern string or nil if not supported
      def locale_pattern(key)
      end

      # Generates a pattern to match cache keys for a specific translation key.
      #
      # @param key [String, Symbol] the translation key
      # @return [String, nil] pattern string or nil if not supported
      def scoped_pattern(key)
      end

      # Generates a pattern to match all I18n cache keys.
      #
      # @return [String, nil] pattern string or nil if not supported
      def greedy_pattern
      end
    end

    # Redis cache adaptor using glob patterns for cache key matching.
    #
    # Generates Redis glob-style patterns for selective cache deletion. Redis
    # supports wildcards (* and ?) in its pattern matching through the KEYS or
    # SCAN commands.
    class Redis < Base
      # Declares which cache store classes this adaptor handles.
      #
      # @return [Array<String>] class names of supported Redis stores
      def self.handles
        %w(
          ActiveSupport::Cache::RedisStore
          ActiveSupport::Cache::RedisCacheStore
        )
      end

      # Generates a Redis glob pattern to match all keys for a locale.
      #
      # @param locale [String, Symbol] the locale identifier
      # @return [String] Redis glob pattern (e.g., "i18n/*;en;*/*")
      def locale_pattern(locale)
        "i18n/*;#{locale};*/*"
      end

      # Generates a Redis glob pattern to match keys for a translation key.
      #
      # @param key [String, Symbol] the translation key
      # @return [String] Redis glob pattern (e.g., "i18n/*/user.name/*")
      def scoped_pattern(key)
        "i18n/*/#{key}/*"
      end

      # Generates a Redis glob pattern to match all I18n cache keys.
      #
      # @return [String] Redis glob pattern matching all I18n entries
      def greedy_pattern
        "i18n/*"
      end
    end

    # RegExp cache adaptor using regular expressions for cache key matching.
    #
    # Generates regular expression patterns for selective cache deletion. Used
    # with cache stores that support regexp-based pattern matching (Memory and
    # File stores).
    class RegExp < Base
      # Declares which cache store classes this adaptor handles.
      #
      # @return [Array<String>] class names of supported stores
      def self.handles
        %w(
          ActiveSupport::Cache::MemoryStore
          ActiveSupport::Cache::FileStore
        )
      end

      # Generates a regexp pattern to match all keys for a locale.
      #
      # @param locale [String, Symbol] the locale identifier
      # @return [String] regular expression pattern (e.g., "^i18n/.*;en;.*/")
      def locale_pattern(locale)
        "^i18n/.*;#{locale};.*/"
      end

      # Generates a regexp pattern to match keys for a translation key.
      #
      # @param key [String, Symbol] the translation key
      # @return [String] regular expression pattern (e.g., "^i18n/.*/user.name/")
      def scoped_pattern(key)
        "^i18n/.*/#{key}/"
      end

      # Generates a regexp pattern to match all I18n cache keys.
      #
      # @return [String] regular expression pattern matching all I18n entries
      def greedy_pattern
        "^i18n/"
      end
    end
  end
end
