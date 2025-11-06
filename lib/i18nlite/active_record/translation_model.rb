module I18nLite
  module ActiveRecord
    # ActiveRecord concern providing translation management functionality for I18nLite.
    #
    # This module extends ActiveRecord models with methods to query, insert, update, and
    # manage translations stored in the database. It implements locale fallback mechanisms,
    # hierarchical key prefixes, and optimized bulk operations for translation management.
    #
    # ## Core Concepts
    #
    # ### System Locale (Universe)
    # The system locale (typically `:system` or `:en`, defined by `I18n.system_locale`)
    # serves as the "source of truth" locale that defines the canonical set of translation
    # keys. All other locales should be subsets of this universe. Methods like
    # {untranslated} and {trim_to_universe} operate relative to this reference locale.
    #
    # ### Locale Fallback Chain
    # The `by_preference` methods implement a locale fallback mechanism with a critical
    # constraint: **the translation key must exist in the LAST locale of the fallback chain**
    # to be returned. The methods then prefer values from earlier locales in the chain.
    #
    # For example, with `by_preference('my.key', [:en_US, :en, :system])`:
    # - The key MUST exist in `:system` (the last/fallback locale)
    # - If the key exists in `:en_US`, that translation is returned
    # - Otherwise, if it exists in `:en`, that translation is returned
    # - Otherwise, the `:system` translation is returned
    # - If the key doesn't exist in `:system`, `nil` is returned (even if it exists in `:en_US`)
    #
    # ### Prefix Matching vs Exact Matching
    # - **Prefix matching** ({by_prefix}, {by_prefix_and_preference}): Uses SQL LIKE matching
    #   for hierarchical keys. Key "my.app.title" matches prefix "my.app".
    # - **Exact matching** ({by_preference}, {by_preference!}): Requires exact key match.
    #
    # @example Including in an ActiveRecord model
    #   class Translation < ActiveRecord::Base
    #     include I18nLite::ActiveRecord::TranslationModel
    #   end
    #
    # @example Basic usage with fallback chain
    #   # Assuming system locale is :en
    #   Translation.create(locale: :en, key: 'greeting', translation: 'Hello')
    #   Translation.create(locale: :en, key: 'farewell', translation: 'Goodbye')
    #   Translation.create(locale: :sv, key: 'greeting', translation: 'Hej')
    #
    #   # Falls back to :en when :sv translation doesn't exist
    #   Translation.by_preference('greeting', [:sv, :en])
    #   #=> #<Translation locale: :sv, key: 'greeting', translation: 'Hej'>
    #
    #   Translation.by_preference('farewell', [:sv, :en])
    #   #=> #<Translation locale: :en, key: 'farewell', translation: 'Goodbye'>
    #
    #   # Returns nil because key doesn't exist in last locale (:en)
    #   Translation.create(locale: :sv, key: 'swedish_only', translation: 'Svenska')
    #   Translation.by_preference('swedish_only', [:sv, :en])
    #   #=> nil
    #
    # @example Finding translations by prefix
    #   Translation.create(locale: :en, key: 'app.title', translation: 'My App')
    #   Translation.create(locale: :en, key: 'app.subtitle', translation: 'Awesome')
    #   Translation.create(locale: :en, key: 'other.key', translation: 'Other')
    #
    #   Translation.by_prefix('app', :en)
    #   #=> [#<Translation key: 'app.title'>, #<Translation key: 'app.subtitle'>]
    #
    # @example Bulk insert or update
    #   Translation.insert_or_update([
    #     { locale: :en, key: 'new.key', translation: 'New value' },
    #     { locale: :en, key: 'existing.key', translation: 'Updated value' }
    #   ])
    #   #=> 2
    #
    # @see I18nLite::Backend::DB
    module TranslationModel

      def self.included(model)
        model.extend ClassMethods
      end

      module ClassMethods
        # Retrieves all translations for a specific locale.
        #
        # This is a simple scope that filters translations by locale.
        #
        # @param locale [String, Symbol] the locale to filter by
        # @return [ActiveRecord::Relation] translations matching the locale
        #
        # @example Finding all English translations
        #   Translation.existing(:en)
        #   #=> [#<Translation locale: :en, key: 'greeting'>, ...]
        def existing(locale)
          self.where(locale: locale)
        end

        # Finds translation keys that exist in the system locale but are missing in the given locale.
        #
        # Returns translations from the system locale (universe) whose keys are not present
        # in the specified locale. Useful for identifying which translations need to be
        # provided for a new or incomplete locale.
        #
        # @param locale [String, Symbol] the locale to check for missing translations
        # @return [ActiveRecord::Relation] system locale translations with keys not in the given locale
        #
        # @example Finding untranslated Swedish keys
        #   # System locale has: 'greeting', 'farewell', 'welcome'
        #   # Swedish locale has only: 'greeting'
        #   Translation.untranslated(:sv)
        #   #=> [
        #   #     #<Translation locale: :system, key: 'farewell'>,
        #   #     #<Translation locale: :system, key: 'welcome'>
        #   #   ]
        def untranslated(locale)
          self.where('locale = ? AND key NOT IN(?)', I18n.system_locale, self.existing(locale).pluck(:key))
        end

        # Performs bulk insert or update of translations for a single locale.
        #
        # Inserts new translation records or updates existing ones in a single transaction.
        # All translations in the array must be for the same locale. Uses optimized bulk
        # INSERT for new records and individual UPDATEs for existing records.
        #
        # @param translations [Array<Hash>] array of translation hashes with :locale, :key, :translation keys
        # @return [Integer] total number of translations processed
        #
        # @raise [MultipleLocalesError] if translations contain multiple different locales
        #
        # @example Inserting new translations
        #   Translation.insert_or_update([
        #     { locale: :en, key: 'app.title', translation: 'My App' },
        #     { locale: :en, key: 'app.subtitle', translation: 'Awesome' }
        #   ])
        #   #=> 2
        #
        # @example Updating existing translations
        #   Translation.create(locale: :en, key: 'greeting', translation: 'Hello')
        #   Translation.insert_or_update([
        #     { locale: :en, key: 'greeting', translation: 'Hi there!' }
        #   ])
        #   #=> 1
        #   Translation.find_by(locale: :en, key: 'greeting').translation
        #   #=> "Hi there!"
        #
        # @example Mixed insert and update
        #   Translation.create(locale: :en, key: 'existing', translation: 'Old value')
        #   Translation.insert_or_update([
        #     { locale: :en, key: 'existing', translation: 'Updated' },
        #     { locale: :en, key: 'new_key', translation: 'New value' }
        #   ])
        #   #=> 2
        #
        # @example Error: multiple locales
        #   Translation.insert_or_update([
        #     { locale: :en, key: 'greeting', translation: 'Hello' },
        #     { locale: :sv, key: 'greeting', translation: 'Hej' }
        #   ])
        #   #=> raises MultipleLocalesError
        #
        # @note All operations occur within a database transaction for consistency.
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

        # Finds translations matching a hierarchical key prefix for a specific locale.
        #
        # Uses SQL LIKE matching to find all translations whose keys start with the given
        # prefix followed by a dot. This supports hierarchical key organization like
        # "app.sections.header" where "app" or "app.sections" would be valid prefixes.
        #
        # @param key [String, Symbol] the key prefix to match (without trailing dot)
        # @param locale [String, Symbol] the locale to filter by
        # @return [ActiveRecord::Relation] translations matching the prefix pattern
        #
        # @example Finding all translations under 'app' namespace
        #   Translation.create(locale: :en, key: 'app.title', translation: 'Title')
        #   Translation.create(locale: :en, key: 'app.header.text', translation: 'Header')
        #   Translation.create(locale: :en, key: 'other.key', translation: 'Other')
        #
        #   Translation.by_prefix('app', :en)
        #   #=> [#<Translation key: 'app.title'>, #<Translation key: 'app.header.text'>]
        #
        # @example Nested prefix matching
        #   Translation.by_prefix('app.header', :en)
        #   #=> [#<Translation key: 'app.header.text'>]
        def by_prefix(key, locale)
          where('key LIKE ? AND locale = ?', "#{key}.%", locale)
        end

        # Finds translations matching a hierarchical key prefix with locale fallback.
        #
        # Combines prefix matching with the locale preference mechanism. The key must exist
        # with the given prefix in the LAST locale of the fallback chain, then returns
        # translations preferring values from earlier locales.
        #
        # @param key [String, Symbol] the key prefix to match (without trailing dot)
        # @param locales [Array<String, Symbol>] ordered array of locales from most to least preferred
        # @return [Array<ActiveRecord::Base>] translations matching prefix with fallback applied
        #
        # @example Prefix matching with fallback
        #   Translation.create(locale: :en, key: 'app.title', translation: 'My App')
        #   Translation.create(locale: :en, key: 'app.subtitle', translation: 'Awesome')
        #   Translation.create(locale: :sv, key: 'app.title', translation: 'Min App')
        #
        #   Translation.by_prefix_and_preference('app', [:sv, :en])
        #   #=> [
        #   #     #<Translation locale: :sv, key: 'app.title', translation: 'Min App'>,
        #   #     #<Translation locale: :en, key: 'app.subtitle', translation: 'Awesome'>
        #   #   ]
        #
        # @note For single locale arrays, this delegates to {by_prefix} for efficiency.
        def by_prefix_and_preference(key, locales)
          return by_prefix(key, locales.first) if locales.size == 1

          q = coalesce_query(locales, key_like: key)
          find_by_sql([q.query, q.params])
        end

        # Finds a single translation by exact key with locale fallback.
        #
        # Implements the core fallback mechanism: the key MUST exist in the LAST locale
        # of the fallback chain to be returned. The method then prefers values from
        # earlier (more preferred) locales in the chain.
        #
        # This constraint ensures translations only exist within the defined "universe"
        # of the fallback locale (typically the system locale).
        #
        # @param key [String, Symbol] the exact translation key to find
        # @param locales [Array<String, Symbol>] ordered array of locales from most to least preferred
        # @return [ActiveRecord::Base, nil] the translation record, or nil if not found in fallback locale
        #
        # @example Basic fallback behavior
        #   Translation.create(locale: :en, key: 'greeting', translation: 'Hello')
        #   Translation.create(locale: :sv, key: 'greeting', translation: 'Hej')
        #
        #   Translation.by_preference('greeting', [:sv, :en])
        #   #=> #<Translation locale: :sv, key: 'greeting', translation: 'Hej'>
        #
        #   Translation.by_preference('greeting', [:de, :sv, :en])
        #   #=> #<Translation locale: :sv, key: 'greeting', translation: 'Hej'>
        #
        # @example Fallback locale constraint
        #   # Key exists in :sv but NOT in :en (the fallback)
        #   Translation.create(locale: :sv, key: 'swedish_only', translation: 'Svenska')
        #
        #   Translation.by_preference('swedish_only', [:sv, :en])
        #   #=> nil  # Returns nil because key doesn't exist in :en
        #
        # @example Falling back to last locale
        #   Translation.create(locale: :en, key: 'farewell', translation: 'Goodbye')
        #
        #   Translation.by_preference('farewell', [:sv, :de, :en])
        #   #=> #<Translation locale: :en, key: 'farewell', translation: 'Goodbye'>
        #
        # @note For single locale arrays, this delegates to `find_by` for efficiency.
        def by_preference(key, locales)
          return find_by(key: key, locale: locales.first) if locales.size == 1

          q = coalesce_query(locales, key: key)
          result = find_by_sql([q.query, q.params])
          return (result.size) ? result.first : nil
        end

        # Finds a single translation by exact key with locale fallback, raising if not found.
        #
        # Behaves identically to {by_preference} but raises an exception instead of
        # returning nil when the translation is not found in the fallback locale.
        #
        # @param key [String, Symbol] the exact translation key to find
        # @param locales [Array<String, Symbol>] ordered array of locales from most to least preferred
        # @return [ActiveRecord::Base] the translation record
        #
        # @raise [ActiveRecord::RecordNotFound] if translation not found in fallback locale
        #
        # @example Successful lookup
        #   Translation.create(locale: :en, key: 'greeting', translation: 'Hello')
        #   Translation.by_preference!('greeting', [:sv, :en])
        #   #=> #<Translation locale: :en, key: 'greeting', translation: 'Hello'>
        #
        # @example Raising on missing translation
        #   Translation.by_preference!('nonexistent', [:en])
        #   #=> raises ActiveRecord::RecordNotFound
        def by_preference!(key, locales)
          self.by_preference(key, locales) or raise ::ActiveRecord::RecordNotFound.new
        end

        # Retrieves all translations with locale fallback applied.
        #
        # Returns all translation keys that exist in the fallback locale (last in the chain),
        # preferring values from earlier locales when available. The result set is limited to
        # the "universe" defined by the fallback locale.
        #
        # @param locales [Array<String, Symbol>] ordered array of locales from most to least preferred
        # @return [Array<ActiveRecord::Base>] all translations in the fallback locale's universe
        #
        # @example Retrieving all translations with fallback
        #   Translation.create(locale: :en, key: 'greeting', translation: 'Hello')
        #   Translation.create(locale: :en, key: 'farewell', translation: 'Goodbye')
        #   Translation.create(locale: :sv, key: 'greeting', translation: 'Hej')
        #
        #   Translation.all_by_preference([:sv, :en])
        #   #=> [
        #   #     #<Translation locale: :sv, key: 'greeting', translation: 'Hej'>,
        #   #     #<Translation locale: :en, key: 'farewell', translation: 'Goodbye'>
        #   #   ]
        #
        # @example Keys outside universe are excluded
        #   Translation.create(locale: :en, key: 'english_key', translation: 'English')
        #   Translation.create(locale: :sv, key: 'swedish_only', translation: 'Svenska')
        #
        #   Translation.all_by_preference([:sv, :en])
        #   #=> [#<Translation key: 'english_key'>]  # swedish_only excluded
        #
        # @note For single locale arrays, returns all translations for that locale.
        # @note Returns an empty array if no translations exist in the fallback locale.
        def all_by_preference(locales)
          return find_by(locale: locales.first) || [] if locales.size == 1

          q = coalesce_query(locales)
          find_by_sql([q.query, q.params])
        end

        # Retrieves all translations as a hash with locale fallback applied.
        #
        # Optimized version of {all_by_preference} that returns a Hash mapping keys to
        # translation values instead of ActiveRecord objects. This provides O(1) lookup
        # performance and reduces memory overhead for large translation sets.
        #
        # @param locales [Array<String, Symbol>] ordered array of locales from most to least preferred
        # @return [Hash{String => String}] hash mapping translation keys to their values
        #
        # @example Fast hash lookup
        #   Translation.create(locale: :en, key: 'greeting', translation: 'Hello')
        #   Translation.create(locale: :en, key: 'farewell', translation: 'Goodbye')
        #   Translation.create(locale: :sv, key: 'greeting', translation: 'Hej')
        #
        #   translations = Translation.all_by_preference_fast([:sv, :en])
        #   #=> {
        #   #     "greeting" => "Hej",
        #   #     "farewell" => "Goodbye"
        #   #   }
        #
        #   # O(1) lookup performance
        #   translations["greeting"]  #=> "Hej"
        #   translations["farewell"]  #=> "Goodbye"
        #
        # @example Empty result
        #   Translation.all_by_preference_fast([:nonexistent])
        #   #=> {}
        #
        # @note This method is significantly faster than {all_by_preference} for large datasets.
        # @note Returns an empty hash if no translations exist in the fallback locale.
        def all_by_preference_fast(locales)
          q = coalesce_query(locales)
          results = find_by_sql([q.query, q.params])
          Hash[*results.map { |record| [record.key, record.translation] }.flatten!]
        end

        # Removes translations with keys not present in the system locale.
        #
        # Deletes all translation records whose keys don't exist in the system locale
        # (universe). This cleanup operation ensures all locales remain synchronized with
        # the canonical key set defined by `I18n.system_locale`. If the system locale has
        # no translations, ALL translations are removed.
        #
        # @param locale [String, Symbol] the locale to trim (unused parameter, affects all locales)
        # @return [void]
        #
        # @example Removing orphaned translations
        #   # System locale defines the universe
        #   Translation.create(locale: :system, key: 'valid.key', translation: 'Valid')
        #
        #   # Other locales can have extra keys
        #   Translation.create(locale: :sv, key: 'valid.key', translation: 'Giltig')
        #   Translation.create(locale: :sv, key: 'orphaned.key', translation: 'Överbliven')
        #
        #   Translation.trim_to_universe(:sv)
        #   # Deletes the 'orphaned.key' translation from :sv
        #   Translation.where(key: 'orphaned.key').count  #=> 0
        #
        # @example Empty universe removes everything
        #   Translation.create(locale: :sv, key: 'some.key', translation: 'Något')
        #
        #   # No translations in system locale
        #   Translation.trim_to_universe(:sv)
        #   Translation.count  #=> 0
        #
        # @note The `locale` parameter is currently unused; this method operates on all locales.
        # @note This operation permanently deletes records and cannot be undone.
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

        # Partitions translations into existing and new records for the given locale.
        #
        # Splits the translation array into two groups: translations that need updating
        # (keys already exist in the locale) and translations that need inserting (new keys).
        # All translations must be for the same locale.
        #
        # @param translations [Array<Hash>] translation hashes with :locale, :key, :translation
        # @return [Array<(Array<Hash>, Array<Hash>)>] tuple of [to_update, to_insert] arrays
        #
        # @raise [MultipleLocalesError] if translations contain multiple different locales
        #
        # @example Partitioning mixed translations
        #   Translation.create(locale: :en, key: 'existing', translation: 'Old')
        #
        #   to_update, to_insert = Translation.send(:partition_on_keys, [
        #     { locale: :en, key: 'existing', translation: 'Updated' },
        #     { locale: :en, key: 'new_key', translation: 'New' }
        #   ])
        #
        #   to_update  #=> [{ locale: :en, key: 'existing', translation: 'Updated' }]
        #   to_insert  #=> [{ locale: :en, key: 'new_key', translation: 'New' }]
        #
        # @api private
        def partition_on_keys(translations)
          locale = translations.first[:locale]
          raise MultipleLocalesError.new if translations.find {|t| t[:locale] != locale}

          existing_keys = existing(locale).pluck(:key).map(&:to_sym)

          translations.partition {|t|
            existing_keys.include? t[:key].to_sym
          }
        end

        # Constructs a SQL query implementing locale fallback using COALESCE.
        #
        # Generates a complex SQL query that joins the translation table multiple times
        # (once per locale) and uses COALESCE to select the first non-NULL value from the
        # preferred locales. The fallback locale (last in array) defines the result set.
        #
        # @param locales [Array<String, Symbol>] ordered array of locales from most to least preferred
        # @param options [Hash] query constraints
        # @option options [String, Symbol] :key exact key to match (uses = operator)
        # @option options [String, Symbol] :key_like key prefix to match (uses LIKE operator with .% suffix)
        # @return [QueryWithParams] object containing SQL query string and parameter hash
        #
        # @note FIXME 1: Should require locales to be at least two elements in length
        # @note FIXME 2: This method has grown and should be split up, preferably in a class
        #   that manages all the various cases
        #
        # @example Generated SQL structure (simplified)
        #   # For locales [:sv, :en] with key 'greeting':
        #   #
        #   # SELECT DISTINCT
        #   #   COALESCE(t_0.id, t_1.id) AS id,
        #   #   COALESCE(t_0.key, t_1.key) AS key,
        #   #   COALESCE(t_0.translation, t_1.translation) AS translation
        #   # FROM translations t_1
        #   # LEFT JOIN (SELECT * FROM translations WHERE locale = 'sv') AS t_0
        #   #   ON t_1.id <> t_0.id AND t_1.key = t_0.key
        #   # WHERE t_1.locale = 'en' AND t_1.key = 'greeting'
        #   # ORDER BY key
        #
        # @api private
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

        # Returns column names suitable for bulk INSERT operations.
        #
        # Excludes the primary key column from the column list since it's typically
        # auto-generated by the database.
        #
        # @return [Array<String>] column names excluding the primary key
        #
        # @api private
        def columns_for_insert
          self.column_names - [self.primary_key]
        end
      end

      # Helper class for building parameterized SQL queries.
      #
      # Manages SQL query construction with named parameters, preventing SQL injection
      # by keeping parameter values separate from the query string. Parameters are
      # automatically numbered and can be inserted into the query using placeholders.
      #
      # @example Building a parameterized query
      #   param = QueryWithParams.new
      #   param.query = "SELECT * FROM users WHERE name = #{param.insert('Alice')} AND age = #{param.insert(30)}"
      #   param.query   #=> "SELECT * FROM users WHERE name = :p0 AND age = :p1"
      #   param.params  #=> { p0: "Alice", p1: 30 }
      #
      # @api private
      class QueryWithParams
        # @return [String] the SQL query string with parameter placeholders
        attr_accessor :query

        # @return [Hash{Symbol => Object}] hash of parameter names to values
        attr_accessor :params

        # Initializes a new query builder with an empty parameter set.
        def initialize
          @params = {}
        end

        # Inserts a value as a named parameter and returns the placeholder.
        #
        # Adds the value to the internal parameter hash with an auto-generated
        # name (:p0, :p1, etc.) and returns the placeholder string for use in
        # the SQL query.
        #
        # @param value [Object] the parameter value to insert
        # @return [String] the parameter placeholder (e.g., ":p0")
        #
        # @example Inserting multiple parameters
        #   param = QueryWithParams.new
        #   placeholder1 = param.insert('Alice')  #=> ":p0"
        #   placeholder2 = param.insert(30)       #=> ":p1"
        #   param.params  #=> { p0: "Alice", p1: 30 }
        def insert(value)
          key = :"p#{@params.size}"
          @params[key] = value
          ":#{key}"
        end

        # Returns the parameter hash.
        #
        # @return [Hash{Symbol => Object}] hash of parameter names to values
        def params
          @params
        end
      end

      # Exception raised when translations contain multiple different locales.
      #
      # Raised by {ClassMethods#insert_or_update} when attempting to bulk insert/update
      # translations that span multiple locales. The method requires all translations
      # in a single batch to be for the same locale.
      #
      # @example Single batch must have consistent locale
      #   Translation.insert_or_update([
      #     { locale: :en, key: 'greeting', translation: 'Hello' },
      #     { locale: :sv, key: 'greeting', translation: 'Hej' }
      #   ])
      #   #=> raises MultipleLocalesError
      class MultipleLocalesError < Exception
      end
    end
  end
end
