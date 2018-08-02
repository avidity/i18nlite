module I18nLite
  module ActiveRecord
    class BulkInsert
      def initialize(table, columns, data)
        @table = table
        @columns = columns
        @data = data
      end

      def execute
        ::ActiveRecord::Base.connection.execute(insert_sql)
      end

      private

      def insert_sql
        <<-SQL
          INSERT INTO #{@table} #{columns_for_insert} VALUES #{values_for_insert}
        SQL
      end

      def columns_for_insert
        "(#{@columns.join(',')})"
      end

      def values_for_insert
        current_timestamp = DateTime.now.utc.iso8601.to_s
        values_strs = []

        @data.each do |row_data|
          values_strs << sql_values_str_for_row(row_data)
        end

        values_strs.join(',')
      end

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

      def symbolized_column_names
        @_symbolized_column_names ||= @columns.map(&:to_sym)
      end

      def timestamp?(column_name)
        column_name == :created_at || column_name == :updated_at
      end

      def current_timestamp
        @_current_timestamp ||= DateTime.now.utc.iso8601.to_s
      end
    end
  end
end
