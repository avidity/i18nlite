module I18nLite
  module ActiveRecord
    module TranslationModel

      def self.included(model)
        model.scope :existing, ->(locale) {
          model.where(locale: locale)
        }

        model.scope :untranslated, ->(locale) {
          model.where('locale = ? AND key NOT IN(?)', I18n.system_locale, model.existing(locale).pluck(:key))
        }

        model.extend ClassMethods
      end

      module ClassMethods
        def insert_or_update(translations)
          to_update, to_insert = partition_on_keys(translations)

          ::ActiveRecord::Base.transaction do
            # FIXME: Resolve this somehow:
            #self.locale_model.insert_missing(translations.first[:locale]) if translations.size

            BulkInsert.new(
              self.table_name,
              columns_for_insert,
              to_insert
            ).execute unless to_insert.empty?

            to_update.each do |t|
              where(
                key:    t[:key],
                locale: t[:locale]
              ).update_all(
                translation: t[:translation]
              )
            end
          end

          return translations.size
        end

        def by_prefix(key, locale)
          where('key LIKE ? AND locale = ?', "#{key}.%", locale)
        end

        def by_prefix_and_preference(key, locales)
          return by_prefix(key, locales.first) if locales.size == 1

          q = coalesce_query(locales, key_like: key)
          find_by_sql([q.query, q.params])
        end

        def by_preference(key, locales)
          return find_by(key: key, locale: locales.first) if locales.size == 1

          q = coalesce_query(locales, key: key)
          result = find_by_sql([q.query, q.params])
          return (result.size) ? result.first : nil
        end

        def by_preference!(key, locales)
          self.by_preference(key, locales) or raise ::ActiveRecord::RecordNotFound.new
        end

        def all_by_preference(locales)
          return find_by(locale: locales.first) || [] if locales.size == 1

          q = coalesce_query(locales)
          find_by_sql([q.query, q.params])
        end

        def all_by_preference_fast(locales)
          q = coalesce_query(locales)
          results = find_by_sql([q.query, q.params])
          Hash[*results.map { |record| [record.key, record.translation] }.flatten!]
        end

        def trim_to_universe(locale)
          universe = self.where(locale: I18n.system_locale).pluck(:key)

          if universe.empty?
            self.destroy_all
          else
            unused_keys = self.where('key not in(?)', universe).pluck(:key)
            self.where(key: unused_keys).destroy_all unless unused_keys.empty?
          end
        end

        private

        def partition_on_keys(translations)
          locale = translations.first[:locale]
          raise MultipleLocalesError.new if translations.find {|t| t[:locale] != locale}

          existing_keys = existing(locale).pluck(:key).map(&:to_sym)

          translations.partition {|t|
            existing_keys.include? t[:key].to_sym
          }
        end

        def coalesce_query(locales, options={})

          # FIXME 1: Require locales to be at least two elements in length'
          # FIXME 2: This method has grown, it should be split up, preferably in a class that manages all the various cases

          param = QueryWithParams.new

          tables = 0.upto(locales.size - 1).map {|i| "t_#{i}" }   # Aliases tables, in order of preference
          fallback_table  = tables.last
          fallback_locale = locales.last
          joins  = (locales.size - 2).downto(0).map {|i|
            table   = tables[i]
            locale  = locales[i]

            "LEFT JOIN (SELECT #{self.column_names.join(', ')} FROM #{self.table_name} WHERE locale = #{param.insert(locale)})
              AS #{table}
              ON  #{fallback_table}.id <> #{table}.id
              AND #{fallback_table}.key = #{table}.key
            "
          }

          coalece_fields = self.column_names.map { |f|
            "COALESCE(#{tables.map {|t| "#{t}.#{f}"}.join(', ')}) AS #{f}"
          }

          if options.has_key?(:key) || options.has_key?(:key_like)
            if options.has_key?(:key_like)
              key_operator = 'LIKE'
              key = "#{options[:key_like]}.%"
            else
              key_operator = '='
              key = options[:key]
            end

            key_constraint = " AND #{fallback_table}.key #{key_operator} #{param.insert(key)}"
          end

          param.query = "SELECT DISTINCT
            #{coalece_fields.join(",\n")}
          FROM #{self.table_name} #{fallback_table}
            #{joins.join("\n")}
          WHERE
            #{fallback_table}.locale = #{param.insert(fallback_locale)}
            #{key_constraint}
          ORDER BY key"

          param
        end

        def columns_for_insert
          self.column_names - [self.primary_key]
        end
      end

      class QueryWithParams
        attr_accessor :params, :query
        def initialize
          @params = {}
        end

        def insert(value)
          key = :"p#{@params.size}"
          @params[key] = value
          ":#{key}"
        end

        def params
          @params
        end
      end

      class MultipleLocalesError < Exception
      end
    end
  end
end
