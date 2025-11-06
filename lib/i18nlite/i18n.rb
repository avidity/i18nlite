module I18n
  @@fallback_list = {}

  class << self

    # Retrieves the fallback locale list for translation lookups.
    #
    # Returns an ordered array of locales to check when resolving translations.
    # The list is dynamically maintained to ensure the requested locale is always
    # first and the system locale is always last. The list is cached per locale
    # and modified in-place to maintain proper ordering.
    #
    # @param locale [Symbol] the locale to get fallbacks for
    # @return [Array<Symbol>] ordered list of locale identifiers to try in sequence
    #
    # @example Get fallback list for current locale
    #   I18n.fallback_list
    #   # => [:en, :system]
    #
    # @example Get fallback list for specific locale
    #   I18n.fallback_list(:fr)
    #   # => [:fr, :en, :system]
    #
    # @note The returned array is modified in-place to ensure the requested locale
    #   is always positioned first and the system locale is always last.
    #
    # NEW: Move to something based on I18n::Locale::Fallbacks instead
    # and that is using the same interface
    def fallback_list(locale=I18n.locale)
      list = @@fallback_list[locale] ||= []

      list.unshift(locale)          unless list.first == locale
      list.push(I18n.system_locale) unless list.last  == I18n.system_locale
      list
    end

    # Sets the fallback locale list for the current locale.
    #
    # Allows customization of the locale fallback chain for translation lookups.
    # If the provided value is not an array, an empty fallback list is set.
    #
    # @param new_fallbacks [Array<Symbol>, Object] array of locale identifiers, or
    #   any other value (which results in an empty fallback list)
    # @return [Array<Symbol>] the assigned fallback list (empty array if input was not an Array)
    #
    # @example Set custom fallback chain
    #   I18n.fallback_list = [:en, :de, :fr]
    #
    # @example Clear fallback list by passing non-array
    #   I18n.fallback_list = nil
    #   # => []
    #
    def fallback_list=(new_fallbacks)
      @@fallback_list[I18n.locale] = if new_fallbacks.kind_of? Array
        new_fallbacks
      else
        []
      end
    end

    # Retrieves locale metadata for the current locale.
    #
    # Returns a LocaleMeta object containing locale-specific information such as
    # display names, text direction, and other metadata. The behavior depends on
    # the configured backend:
    # - DB backend: Returns metadata from the database
    # - Other backends: Returns an empty LocaleMeta object
    #
    # @return [I18nLite::Backend::LocaleMeta] metadata object for the current locale
    #
    # @example Get metadata with DB backend
    #   meta = I18n.meta
    #   meta.display_name  # => "English"
    #
    # @example Get metadata with non-DB backend
    #   meta = I18n.meta
    #   # Returns empty LocaleMeta object
    #
    # @note Non-DB backends return an empty LocaleMeta object rather than nil.
    #   This ensures consistent return type across all backend implementations.
    #
    def meta
      if I18n.backend.kind_of? I18nLite::Backend::DB
        I18n.backend.meta(I18n.locale)
      else
        I18nLite::Backend::LocaleMeta.new
      end
    end

    # Returns the system locale identifier.
    #
    # The system locale acts as the final fallback in the locale chain and
    # typically represents translations that are always available regardless
    # of the current locale setting.
    #
    # @return [Symbol] the system locale identifier (always :system)
    #
    # @example
    #   I18n.system_locale  # => :system
    #
    # NEW: Should we use default locale instead?
    def system_locale
      :system
    end
  end
end
