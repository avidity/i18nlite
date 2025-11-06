module I18nLite
  module ActiveRecord
    # Performs bulk INSERT operations for improved database performance.
    #
    # Generates a single SQL INSERT statement with multiple value sets, which is
    # significantly faster than individual INSERT statements. Automatically handles
    # timestamp columns (created_at, updated_at) by setting them to the current time.
    #
    # @example Bulk inserting translations
    #   bulk_insert = BulkInsert.new(
    #     'translations',
    #     ['key', 'locale', 'translation', 'created_at', 'updated_at'],
    #     [
    #       { key: 'greeting', locale: 'en', translation: 'Hello' },
    #       { key: 'farewell', locale: 'en', translation: 'Goodbye' }
    #     ]
    #   )
    #   bulk_insert.execute
    #   # Executes: INSERT INTO translations (key,locale,translation,created_at,updated_at)
    #   #           VALUES ('greeting','en','Hello','2024-01-01T12:00:00Z','2024-01-01T12:00:00Z'),
    #   #                  ('farewell','en','Goodbye','2024-01-01T12:00:00Z','2024-01-01T12:00:00Z')
    #
    # @note All rows in a single bulk insert will have identical timestamp values.
    class BulkInsert
      # Initializes a bulk insert operation.
      #
      # @param table [String] the database table name
      # @param columns [Array<String, Symbol>] column names to insert into
      # @param data [Array<Hash>] array of hashes, each representing a row with column => value pairs
      def initialize(table, columns, data)
        @table = table
        @columns = columns
        @data = data
      end

      # Executes the bulk insert SQL statement.
      #
      # @return [void]
      def execute
        ::ActiveRecord::Base.connection.execute(insert_sql)
      end

      private

      # Constructs the complete SQL INSERT statement.
      #
      # @return [String] SQL statement with table, columns, and values
      def insert_sql
        <<-SQL
          INSERT INTO #{@table} #{columns_for_insert} VALUES #{values_for_insert}
        SQL
      end

      # Formats column names for the SQL INSERT statement.
      #
      # @return [String] comma-separated column names wrapped in parentheses
      def columns_for_insert
        "(#{@columns.join(',')})"
      end

      # Generates the VALUES clause for all rows in the bulk insert.
      #
      # @return [String] comma-separated value sets, each wrapped in parentheses
      def values_for_insert
        current_timestamp = DateTime.now.utc.iso8601.to_s
        values_strs = []

        @data.each do |row_data|
          values_strs << sql_values_str_for_row(row_data)
        end

        values_strs.join(',')
      end

      # Formats a single row's values for the SQL INSERT statement.
      #
      # Automatically fills timestamp columns (created_at, updated_at) with the current
      # timestamp and properly quotes all values to prevent SQL injection.
      #
      # @param data [Hash] row data with column names as keys
      # @return [String] quoted and comma-separated values wrapped in parentheses
      def sql_values_str_for_row(data)
        values_ary = symbolized_column_names.map do |col|
          value = if timestamp?(col)
            current_timestamp
          else
            data[col]
          end

          ::ActiveRecord::Base.connection.quote(value)
        end

        "(#{values_ary.join(',')})"
      end

      # Returns memoized symbolized column names.
      #
      # @return [Array<Symbol>] column names as symbols
      def symbolized_column_names
        @_symbolized_column_names ||= @columns.map(&:to_sym)
      end

      # Checks if a column is a timestamp column.
      #
      # @param column_name [Symbol] the column name to check
      # @return [Boolean] true if column is created_at or updated_at
      def timestamp?(column_name)
        column_name == :created_at || column_name == :updated_at
      end

      # Returns the memoized current timestamp in ISO8601 format.
      #
      # @return [String] UTC timestamp in ISO8601 format
      def current_timestamp
        @_current_timestamp ||= DateTime.now.utc.iso8601.to_s
      end
    end
  end
end
