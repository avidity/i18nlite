require 'murmurhash3'

module I18nLite
  module Backend
    module ConsistentCache
      include I18n::Backend::Cache

      def cache_key(locale, key, options)
        locale_key = if I18n.respond_to? :fallback_list
          I18n.fallback_list(locale).join(';')
        else
          locale
        end

        hash = (options.empty?) ? '' : MurmurHash3::V32.str_hash(options.values.join(';'))
        # NOTE: The tailing "/" when options are empty is intentional!
        "i18n/;#{locale_key};/#{key}/#{hash}"
      end

      def meta_cache_key(locale)
        "i18n/meta/#{locale}"
      end
    end
  end
end
