module I18nLite
  class << self

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
