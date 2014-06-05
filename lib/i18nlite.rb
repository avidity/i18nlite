require 'i18n'
require 'i18nlite/i18n'
require 'i18nlite/backend/consistant_cache'
require 'i18nlite/backend/db'
require 'i18nlite/backend/simple_importer'
require 'i18nlite/active_record/model'
require "i18nlite/with_locale"
require "i18nlite/cache_control"
require "i18nlite/error"
require "i18nlite/importer/xml"
require "i18nlite/importer/simple_backend"

# All these 4 dependencies can go when compat is no longer needed
require 'active_support/concern'
require 'action_controller'
require 'rails'
require "promote_i18n/compat"

module I18nLite
end

module PromoteI18n
end
