module I18n
  @@fallback_list = []

  class << self

    def fallback_list
      @@fallback_list.unshift(I18n.locale)      unless @@fallback_list.first == I18n.locale
      @@fallback_list.push(I18n.system_locale)  unless @@fallback_list.last  == I18n.system_locale
      @@fallback_list
    end

    def fallback_list=(new_fallbacks)
      if new_fallbacks.kind_of? Array
        @@fallback_list = new_fallbacks
      else
        @@fallback_list = []
      end
    end

    def system_locale
      :system
    end
  end
end
