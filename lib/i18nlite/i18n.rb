module I18n
  @@fallback_list = {}

  class << self

    # NEW: Move to something based on I18n::Locale::Fallbacks instead
    # and that is using the same interface
    def fallback_list(locale=I18n.locale)
      list = @@fallback_list[locale] ||= []

      list.unshift(locale)          unless list.first == locale
      list.push(I18n.system_locale) unless list.last  == I18n.system_locale
      list
    end

    def fallback_list=(new_fallbacks)
      @@fallback_list[I18n.locale] = if new_fallbacks.kind_of? Array
        new_fallbacks
      else
        []
      end
    end

    def meta
      if I18n.backend.kind_of? I18nLite::Backend::DB
        I18n.backend.meta(I18n.locale)
      else
        I18nLite::Backend::LocaleMeta.new
      end
    end

    # NEW: Should we use default locale instead?
    def system_locale
      :system
    end
  end
end
