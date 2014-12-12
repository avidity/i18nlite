module I18nLite
  module Compat
    def method_missing(method, *args, &block)
      klass = if self.instance_of?(Class) || self.instance_of?(Module)
        self
      else
        self.class
      end

      Rails.logger.info("DEPRECATION WARNING: #{self}##{method} is deprecated in favour of #{klass.compat_delegate_to}##{method} called at #{caller(0)[1]}")
      klass.compat_delegate_to.send(method, *args, &block)
    end
  end
end


module PromoteI18n
  module CacheControl
    class << self
      include I18nLite::Compat

      def compat_delegate_to
        I18nLite::CacheControl
      end
    end
  end

  class << self
    include I18nLite::Compat

    def compat_delegate_to
      I18nLite
    end
  end

  module FallbackChain
    extend ActiveSupport::Concern

    module ClassMethods
      def fallback_chains(locale, chain)
        Rails.logger.info("DEPRECATION WARNING: fallback_chains is deprecated, use I18n.fallbacks = [your, fallback, locales] instead called at #{caller(0)[1]}")

        locale = locale.call if locale.is_a? Proc
        chain = chain.call if chain.is_a? Proc

        unless locale.is_a?(Symbol)
          raise "Passed locale should be a Symbol"
        end

        unless (chain.is_a? Symbol or chain.is_a? Array)
          raise "Please, inform chain as an array or symbol"
        end

        chain = Array(chain)
        unless chain.map{|c| c.class == Symbol}.all?
          raise "fallback_chains expects a list of Symbols only."
        end

        I18n.fallbacks = chain
      end
    end
  end

  class RaiseTranslationMissingHandler
    include I18nLite::Compat

    class << self
      def compat_delegate_to
        I18nLite::Error::RaiseMissingHandler
      end
    end
  end

end

ActionController::Base.send :include, PromoteI18n::FallbackChain
