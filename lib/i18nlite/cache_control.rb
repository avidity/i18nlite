module I18nLite
  module CacheControl

    #
    # Provides the interface to keyed cache control:
    # You'll be mostly concerned with:
    #  > PromoteI18n::CacheControl.clear_keys(:'my.string', :'my_other_string')
    #
    # You may need to clear all cached keys
    #  > PromoteI18n::CacheControl.clear_all
    #
    # But may find this handy:
    #  > PromoteI18n::CacheControl.can_clear_keys?
    # =>  true # or false
    #
    # You can access the adaptor directly
    #  > PromoteI18n::CacheControl.adaptor
    # => an instance that that can deal with the configured cache store
    #

    class << self
      def clear_keys(*keys)
        begin
          keys.each do |key|
            I18n.cache_store.delete_matched( adaptor.scoped_pattern(key) )
          end
        rescue NotImplementedError
          I18n.cache_store.clear
        end
      end

      def clear_locale(locale)
        begin
          I18n.cache_store.delete_matched( adaptor.locale_pattern(locale) )
        rescue NotImplementedError
          I18n.cache_store.clear
        end
      end

      def clear_all
        begin
          I18n.cache_store.delete_matched( adaptor.greedy_pattern )
        rescue NotImplementedError
          I18n.cache_store.clear
        end
      end

      def can_clear_keys?
        adaptor.greedy_pattern.present?
      end

      def adaptor
        KeyedCacheAdaptor::Base.adaptor_for( I18n.cache_store )
      end
    end
  end

  module KeyedCacheAdaptor
    class Base
      def self.adaptor_for(store)
        @@adaptors ||= {}
        @@adaptors[store.class.to_s.to_sym] ||= (self.subclasses.find do
          |subclass|
          begin
            subclass.handles.any? do
              |supported_store|
              store.instance_of?(supported_store.constantize)
            end
          rescue NameError
            false
          end
        end || self).new
      end

      def locale_pattern(key)
      end

      def scoped_pattern(key)
      end

      def greedy_pattern
      end
    end

    class Redis < Base
      def self.handles
        %w(
          ActiveSupport::Cache::RedisStore
        )
      end

      def locale_pattern(locale)
        "i18n/*;#{locale};*/*"
      end

      def scoped_pattern(key)
        "i18n/*/#{key}/*"
      end

      def greedy_pattern
        "i18n/*"
      end
    end

    class RegExp < Base
      def self.handles
        %w(
          ActiveSupport::Cache::MemoryStore
          ActiveSupport::Cache::FileStore
        )
      end

      def locale_pattern(locale)
        "^i18n/.*;#{locale};.*/"
      end

      def scoped_pattern(key)
        "^i18n/.*/#{key}/"
      end

      def greedy_pattern
        "^i18n/"
      end
    end
  end
end