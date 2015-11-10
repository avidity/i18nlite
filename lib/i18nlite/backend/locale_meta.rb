module I18nLite
  module Backend
    class LocaleMeta < Hash

      def respond_to?(prop, *args)
        return true if self.has_key? prop.to_s
        super
      end

      def method_missing(prop, *args)
        self.fetch(prop.to_s) do
          super
        end
      end

      def direction
        if self.rtl?
          'rtl'
        else
          'ltr'
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
