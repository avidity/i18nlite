module I18n
  @@fallback_list = {}

  class << self

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

    def system_locale
      :system
    end
  end
end
