module I18nLite
  module Error
    # Raises translation errors just as
    # I18n.exception_handler = I18nLite::RaiseMissingHandler.new

    class RaiseMissingHandler
      def self.call(*args)
        new.call(*args)
      end

      def call(exception, locale, key, options)
        raise I18n::MissingTranslationData.new(locale, key, options)
      end
    end
  end
end
