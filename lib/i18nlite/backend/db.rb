# FIXME: Rename project

module I18nLite
  module Backend
    class DB
      include I18n::Backend::Base
      include I18n::Backend::Flatten
      include I18nLite::Backend::ConsistentCache

      attr_accessor :model

      def initialize(model)
        @model = model
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

        # NOTE: I was under the impression that this statement would be smart an generate
        # INSERT INTO ... (col1, col2, ...) VALUES
        #  (row1, row1, ...)
        #  (row2, row2, ...)
        # but instead activecrecord just generates multiple inserts. We might want to change that
        # for performance reasons

        @model.create(translations)
      end

      def available_locales
        locales = @model.all_locales.map {|l| l.to_sym }
        locales.unshift(:en) unless locales.include?(:en)
        locales
      end

      def all_flattened
        @model.all_by_preference_fast(locales)
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
            # If no match was found, we return nil, causing a missing translation error

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
          @model.by_prefix(norm_key, record.locale).pluck(:translation)
        else
          record.translation
        end
      end
    end
  end
end
