module I18nLite
  # Error handling for I18n translations.
  #
  # This module provides exception handlers that can be used to customize
  # how I18n handles missing translations. By default, I18n returns placeholder
  # strings for missing translations, but these handlers can enforce stricter
  # behavior by raising exceptions.
  #
  # @example Configure I18n to raise exceptions for missing translations
  #   I18n.exception_handler = I18nLite::Error::RaiseMissingHandler.new
  module Error
    # Exception handler that raises errors for missing translations.
    #
    # This handler can be set as the I18n exception handler to enforce that
    # all translations are present. When a translation is missing, it raises
    # an I18n::MissingTranslationData exception instead of returning a
    # placeholder string.
    #
    # This is particularly useful in test or development environments where
    # you want to catch missing translations immediately, or in production
    # environments where missing translations should be treated as critical errors.
    #
    # @example Set as I18n exception handler
    #   I18n.exception_handler = I18nLite::Error::RaiseMissingHandler.new
    #
    # @example Use with callable class method
    #   I18n.exception_handler = I18nLite::Error::RaiseMissingHandler
    class RaiseMissingHandler
      # Convenience class method that creates an instance and delegates to it.
      #
      # This allows the class itself to be used as a callable exception handler
      # without explicitly instantiating it.
      #
      # @param args [Array] arguments passed through to the instance call method
      # @return [void]
      # @raise [I18n::MissingTranslationData] always raises for missing translations
      #
      # @example Use class as callable handler
      #   I18n.exception_handler = I18nLite::Error::RaiseMissingHandler
      def self.call(*args)
        new.call(*args)
      end

      # Handles missing translation exceptions by raising them.
      #
      # This method conforms to the I18n exception handler interface. When
      # invoked by I18n for a missing translation, it raises an exception
      # containing the locale, key, and options that were attempted.
      #
      # @param exception [Exception] the original exception (typically unused)
      # @param locale [Symbol, String] the locale that was being used
      # @param key [Symbol, String] the translation key that was not found
      # @param options [Hash] additional options passed to the translation lookup
      #
      # @return [void]
      # @raise [I18n::MissingTranslationData] always raises with locale, key, and options
      #
      # @example Typical usage by I18n internals
      #   handler.call(nil, :en, 'user.name', {scope: :errors})
      def call(exception, locale, key, options)
        raise I18n::MissingTranslationData.new(locale, key, options)
      end
    end
  end
end
