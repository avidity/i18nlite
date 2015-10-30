module I18nLite
  module ActiveRecord
    module LocaleModel
      def self.included(model)
        model.extend ClassMethods
      end

      module ClassMethods
        def all_locales
          self.select(:locale)
              .order(:locale)
              .pluck(:locale)
        end

        def insert_missing(*locales)
          existing = all_locales
          spec = locales.delete_if { |l| existing.include? l.to_s }
                        .map { |l| { locale: l } }
          self.create(spec) unless spec.empty?
        end
      end
    end
  end
end

