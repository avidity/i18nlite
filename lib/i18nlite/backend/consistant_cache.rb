require 'murmurhash3'

module I18nLite
  module Backend
    module ConsistentCache
      include I18n::Backend::Cache

      def cache_key(locale, key, options)
        hash = (options.empty?) ? '' : MurmurHash3::V32.str_hash(options.values.join(';'))
        "i18n/#{locale}/#{key}/#{hash}"
      end
    end
  end
end
