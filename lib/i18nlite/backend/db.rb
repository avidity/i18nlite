require 'i18nlite/backend/consistant_cache'
require 'i18nlite/backend/locale_meta'

module I18nLite
  module Backend
    class DB
      include I18n::Backend::Base
      include I18n::Backend::Flatten
      include I18nLite::Backend::ConsistentCache

      attr_accessor :model, :locale_model

      def initialize(options)
        @model = options.fetch(:translation_model)
        @locale_model = options.fetch(:locale_model)
        super()
      end

      def store_translations(locale, data, options = {})

        translations = []
        flatten_translations(nil, data, false, false).each_pair do |key, value|
          if value.kind_of?(Array)
            value.each_with_index do |t, i|
              translations.push({
                key: "#{key}.#{i}",
                locale: locale,
                translation: t
              })
            end
            translations.push({
              key: key,
              locale: locale,
              is_array: true
            })
          else
            translations.push({
              key: key,
              locale: locale,
              translation: value
            })
          end
        end

        # Weed out existing translations not in universe
        @model.insert_or_update(translations)
      end

      def available_locales
        @locale_model.all_locales.map {|l| l.to_sym }
      end

      def all_flattened
        @model.all_by_preference_fast(locales)
      end

      def all_expanded
        flattened = @model.all_by_preference_fast(locales)
        expanded = {}

        flattened.each {|long_key, value|
          keys = long_key.to_s.split('.')
          i    = 0

          keys.reduce(expanded) {|hash_ref, key|
            hash_ref[key] = if (i += 1) == keys.size
              value
            else
              hash_ref[key] || {}
            end
          }
        }

        expanded
      end

      def meta(locale)
        if I18n.cache_store
          I18n.cache_store.fetch( meta_cache_key(locale) ) do
            get_meta(locale)
          end
        else
          get_meta(locale)
        end
      end

    protected

      def locales
        I18n.fallback_list || [locale]
      end

      def lookup(locale, key, scope = [], options = {})
        norm_key = self.normalize_flat_keys(locale, key, scope, nil)

        begin
          record = @model.by_preference!(norm_key, locales)
        rescue ::ActiveRecord::RecordNotFound
          if options.has_key?(:count)
            # If we didn't find a direct match, and :count was passed in, we'll
            # try to find matching '.one', '.zero' and pass them on to the magic
            # pluralization engine
            # If no match was found, we return nil, causing a missing translation exception

            result = Hash[
              @model.by_prefix_and_preference(norm_key, locales).map {
                |record|
                # Format the result for the pluralization engine
                [record.key.gsub(/^.+\./, '').to_sym, record.translation]
              }
            ]

            return result unless result.empty?
          end
          return nil
        end

        if record.is_array?
          as_array(@model.by_prefix(norm_key, record.locale).pluck(:key, :translation))
        else
          record.translation
        end
      end

    private

      def get_meta(locale)
        begin
          locale_instance = @locale_model.find_by!(locale: locale)
        rescue ::ActiveRecord::RecordNotFound
          return {}
        end

        I18nLite::Backend::LocaleMeta.new(locale_instance).to_hash
      end

      def as_array(elements)
        elements.sort { |a, b|
          index_from_key(a[0]) <=> index_from_key(b[0])
        }.map { |e|
          e[1]
        }
      end

      def index_from_key(key)
        key[key.rindex(".") + 1..-1].to_i
      end
    end
  end
end
