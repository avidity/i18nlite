module I18nLite
  class << self

    # Temporarily sets the locale and fallback chain for the duration of a block.
    #
    # This method provides a safe way to execute code within a specific locale context.
    # The locale and fallback list are automatically restored to their original values
    # after the block completes, even if an exception is raised.
    #
    # @param chain [Symbol, Array<Symbol>] the locale or locale chain to use. If a
    #   Symbol is provided, it will be converted to a single-element array. The first
    #   element becomes the active locale, and the entire chain defines the fallback order.
    #
    # @yield the block to execute with the temporary locale settings
    #
    # @return [Object] the return value of the provided block
    #
    # @example Using a single locale
    #   I18nLite.with_locale(:sv) do
    #     I18n.t('hello')  # Translates using Swedish locale
    #   end
    #   # Locale is automatically restored after the block
    #
    # @example Using a locale chain with fallbacks
    #   I18nLite.with_locale([:pt_BR, :pt, :en]) do
    #     I18n.t('greeting')  # Uses pt_BR, falls back to pt, then en
    #   end
    #
    # @example Exception safety
    #   I18nLite.with_locale(:fr) do
    #     raise "Error"  # Locale is still restored despite the exception
    #   end
    #
    # @note The system locale (`:system`) is automatically appended to the fallback
    #   list by {I18n.fallback_list}.
    def with_locale(chain)
      chain = [chain] if chain.kind_of? Symbol

      orig_locale    = I18n.locale
      orig_fallbacks = I18n.fallback_list.dup

      I18n.locale = chain.first
      I18n.fallback_list = chain
      begin
        result = yield
      ensure
        I18n.locale = orig_locale
        I18n.fallback_list = orig_fallbacks
      end

      result
    end
  end
end
