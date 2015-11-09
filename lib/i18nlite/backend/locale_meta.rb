module I18nLite
  module Backend
    class LocaleMeta < Hash

      def method_missing(prop, *args)
        self.fetch(prop.to_s) do
          super
        end
      end

      def direction
        if self.rtl?
          'RTL'
        else
          'LTR'
        end
      end

      def rtl?
        self.fetch('rtl', false)
      end

      def ltr?
        !self.rtl?
      end
    end
  end
end
