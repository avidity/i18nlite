module I18nLite
  module Backend
    # Hash subclass providing dynamic property access for locale metadata.
    #
    # Extends Hash to allow accessing stored attributes as method calls, enabling
    # convenient dot-notation access to locale properties. Supports dynamic properties
    # stored in the database such as locale code, font preferences, and text direction.
    #
    # @example Accessing dynamic properties
    #   meta = LocaleMeta.new.merge!('locale' => 'ar', 'font' => 'Arial', 'rtl' => true)
    #   meta.locale  #=> "ar"
    #   meta.font    #=> "Arial"
    #   meta.rtl     #=> true
    #
    # @see I18nLite::ActiveRecord::LocaleModel
    class LocaleMeta < Hash

      # Checks if the object responds to a method, including hash keys.
      #
      # @param prop [Symbol, String] the method name to check
      # @param args [Array] additional arguments (passed to super)
      # @return [Boolean] true if method exists or key is present in hash
      def respond_to?(prop, *args)
        return true if self.has_key? prop.to_s
        super
      end

      # Provides dynamic property access for hash keys.
      #
      # Enables accessing hash values using method call syntax. Falls back to
      # standard method_missing behavior if key is not present.
      #
      # @param prop [Symbol] the property name
      # @param args [Array] additional arguments (unused)
      # @raise [NoMethodError] if property is not in hash and method doesn't exist
      # @return [Object] the value associated with the property key
      def method_missing(prop, *args)
        self.fetch(prop.to_s) do
          super
        end
      end

      # Returns the text direction for the locale.
      #
      # @return [String] "rtl" if right-to-left, "ltr" if left-to-right
      def direction
        if self.rtl?
          'rtl'
        else
          'ltr'
        end
      end

      # Checks if the locale uses right-to-left text direction.
      #
      # @return [Boolean] true if locale is right-to-left, false otherwise
      def rtl?
        self.fetch('rtl', false)
      end

      # Checks if the locale uses left-to-right text direction.
      #
      # @return [Boolean] true if locale is left-to-right, false otherwise
      def ltr?
        !self.rtl?
      end
    end
  end
end
