module I18nLite
  module ActiveRecord
    module LocaleModel
      def self.included(model)
        model.extend ClassMethods
      end

      def meta
        {
          font: self.font,
          direction: self.direction,
          ltr: self.ltr?,
          rtl: self.rtl?,
        }
      end

      def ltr=(bool)
        self.rtl = !bool
      end

      def ltr?
        !rtl?
      end

      def direction
        if rtl?
          'RTL'
        else
          'LTR'
        end
      end

      module ClassMethods
        def translation_model(model=nil)
          unless model.nil?
            raise StandardError.new "translation_model already set" if @translation_model
            @translation_model = model
            setup_arel
          end
          @translation_model
        end

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

        private

        def setup_arel
          self.has_many :translations,
                        class_name: translation_model.name,
                        foreign_key: :locale,
                        primary_key: :locale,
                        dependent: :destroy   # FIXME: delete_all?
        end
      end
    end
  end
end

