module I18nLite
  module Error
    # Raises translation errors just as
    # I18n.exception_handler = PromoteI18n::RaiseTranslationMissingHandler.new

    class RaiseMissingHandler
      def call(exception, locale, key, options)
        raise I18n::MissingTranslationData.new(locale, key, options)
      end
    end

    class RegisterMissingHandler
      def call(exception, locale, key, options)
        exception = I18n::MissingTranslationData.new(locale, key, options)
        if defined? Promote::ExceptionReporter
          Promote::ExceptionReporter.rescue_and_report("Translation missing #{key}, #{locale}") do
            raise exception
          end
        else
          raise exception
        end
      end
    end
  end
end
