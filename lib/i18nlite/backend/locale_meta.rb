module I18nLite
  module Backend
    class LocaleMeta
      attr_accessor :model

      def initialize(model)
        @model = model
      end

      def to_hash
        @model.attributes.merge(
          'direction' => self.direction,
          'ltr'       => self.ltr?
        )
      end

      def direction
        if @model.rtl?
          'RTL'
        else
          'LTR'
        end
      end

      def rtl?
        @model.rtl?
      end

      def ltr?
        !self.rtl?
      end
    end
  end
end
