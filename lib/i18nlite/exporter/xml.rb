require 'nokogiri'
require 'date'
require 'i18nlite/version'


module I18nLite
  module Exporter
    # XML exporter for I18nLite translations and locale metadata.
    #
    # Exports translations and locale metadata to an XML format suitable for external
    # translation tools, version control, or data exchange. Supports exporting either
    # existing translations or untranslated keys with optional reference locale data
    # for comparison.
    #
    # The exporter generates well-formed XML documents with two main sections:
    # - Locale metadata (text direction, font, locale names)
    # - Translation strings with optional reference locale for context
    #
    # Arrays are stored with indexed keys (e.g., "date.day_names.0", "date.day_names.1")
    # and are reconstructed as multiple <translation> elements under a single <string> key.
    #
    # @example Basic export of all locales
    #   exporter = I18nLite::Exporter::XML.new
    #   xml_content = exporter.export
    #   File.write('translations.xml', xml_content)
    #
    # @example Export specific locales with custom reference
    #   exporter = I18nLite::Exporter::XML.new
    #   exporter.locales = [:sv, :no, :da]
    #   exporter.ref_locale = :en
    #   xml_content = exporter.export(:existing)
    #
    # @example Export untranslated keys for a translator
    #   exporter = I18nLite::Exporter::XML.new
    #   exporter.locales = [:fr]
    #   exporter.ref_locale = :en
    #   xml_content = exporter.export(:untranslated)
    #
    # @see XMLTranslations
    # @see XMLLocales
    # @see file:lib/i18nlite/exporter/xml.rb XML format examples (lines 195-276)
    class XML

      # Version string to include in exported XML.
      #
      # @return [String] defaults to "I18nLite v#{I18nLite::VERSION}"
      attr_accessor :version

      # Reference locale for comparison in exported translations.
      #
      # @return [Symbol] defaults to I18n.system_locale
      attr_accessor :ref_locale

      # Locales to export.
      #
      # @return [Array<Symbol>] defaults to I18n.available_locales
      attr_accessor :locales

      # Returns the version string for the exporter.
      #
      # @return [String] version string in format "I18nLite vX.X.X"
      def version
        @version ||= "I18nLite v#{I18nLite::VERSION}"
      end

      # Returns the reference locale for translation comparison.
      #
      # @return [Symbol] the reference locale code
      def ref_locale
        @ref_locale ||= I18n.system_locale
      end

      # Returns the locales to be exported.
      #
      # @return [Array<Symbol>] array of locale codes
      def locales
        @locales ||= I18n.available_locales || []
      end

      # Sets the locales to export, ensuring they are symbols.
      #
      # @param locales [Symbol, String, Array<Symbol, String>] locale(s) to export
      # @return [Array<Symbol>] normalized array of locale symbols
      def locales=(locales)
        @locales = Array(locales).map(&:to_sym)
      end

      # Exports translations and locale metadata to XML format.
      #
      # Generates a complete XML document with locale metadata and translation strings.
      # When exporting locales other than the reference locale, reference translations
      # are included for comparison.
      #
      # @param dataset_type [Symbol] type of translations to export
      #   - :existing - export all existing translations (default)
      #   - :untranslated - export only untranslated keys (empty translations with reference)
      #
      # @return [String] XML document as a string
      #
      # @raise [UnknownLocaleError] if any specified locale is not available
      # @raise [UnknownDatasetError] if dataset_type is not :existing or :untranslated
      #
      # @example Export existing translations
      #   exporter.export(:existing)
      #   # Returns XML with all translated strings
      #
      # @example Export untranslated keys for translation
      #   exporter.export(:untranslated)
      #   # Returns XML with empty translations and reference locale text
      #
      # @see XMLTranslations#add
      # @see XMLLocales#add
      def export(dataset_type=:existing)
        diff = (locales + [ref_locale]) - (I18n.available_locales + [I18n.system_locale])
        unless diff.empty?
          raise I18nLite::Exporter::UnknownLocaleError.new(diff.join(', '))
        end

        builder = Nokogiri::XML::Builder.new do |xml|
          xml.i18n(generated: get_date, version: version) {

            I18nLite::Exporter::XMLLocales
              .new(xml)
              .add( locales )

            I18nLite::Exporter::XMLTranslations
              .new(xml, ref_locale, dataset_type)
              .add( locales )
          }
        end

        return builder.to_xml
      end

      private

      # Returns the current UTC timestamp in ISO8601 format.
      #
      # @return [String] timestamp string (e.g., "2014-05-17T13:10:00Z")
      def get_date
        DateTime.now.utc.iso8601
      end
    end


    # Helper class that exports translation strings to XML format.
    #
    # Handles the generation of <strings> elements containing translation data.
    # Manages reference locale inclusion, array translations, and dataset filtering.
    #
    # Array translations are stored in the database with indexed keys (e.g., "days.0",
    # "days.1") plus a marker entry with is_array=true. This class reconstructs them
    # as multiple <translation> elements in the XML output.
    #
    # @api private
    # @see XML#export
    class XMLTranslations
      # Initializes the translation exporter.
      #
      # @param builder [Nokogiri::XML::Builder] the XML builder instance
      # @param ref_locale [Symbol] the reference locale for comparison
      # @param dataset_type [Symbol] either :existing or :untranslated
      #
      # @raise [UnknownDatasetError] if dataset_type is invalid
      def initialize(builder, ref_locale, dataset_type)
        unless [:untranslated, :existing].include? dataset_type
          raise UnknownDatasetError.new(dataset_type)
        end

        @builder = builder
        @ref_locale = ref_locale
        @dataset_type = dataset_type
        @references = {}
      end

      # Adds translation strings for the specified locales to the XML.
      #
      # For each locale, creates a <strings> element containing all translations.
      # When the locale differs from the reference locale, includes reference
      # translations within each <string> element for comparison.
      #
      # Root array element keys (ending with .0, .1, etc.) are skipped because
      # they are grouped under their parent key and output as multiple <translation>
      # elements.
      #
      # @param locales [Array<Symbol>] locales to export
      # @return [void]
      #
      # @example Generated XML structure
      #   <strings locale="sv" reference-locale="en">
      #     <string key="user.greeting">
      #       <translation>Hej</translation>
      #       <reference>
      #         <translation>Hello</translation>
      #       </reference>
      #     </string>
      #   </strings>
      def add(locales)
        locales.each do |locale|

          attrs = { locale: locale }
          attrs[:'reference-locale'] = @ref_locale if include_reference? locale

          @builder.strings(attrs) {

            dataset(locale).order(:key).each do |translation|
              next if translation.key =~ /\.\d+$/  # Skip root array elements

              if include_reference? locale
                ref_translation = get_reference(translation.key) or next  # Skip if there's no reference locale
              end

              @builder.string(key: translation.key) {
                translation.translation = '' if @dataset_type == :untranslated

                add_translation(translation)

                if ref_translation.present?
                  @builder.reference {
                    add_translation(ref_translation)
                  }
                end
              }
            end
          }
        end
      end

      private

      # Determines whether to include reference locale for comparison.
      #
      # Reference locale is included when the target locale differs from the reference.
      #
      # @param locale [Symbol] the locale being exported
      # @return [Boolean] true if reference should be included
      def include_reference?(locale)
        locale != @ref_locale
      end

      # Retrieves the dataset for a locale based on the dataset type.
      #
      # @param locale [Symbol] the locale to retrieve
      # @return [ActiveRecord::Relation] translation records for the locale
      def dataset(locale)
        I18n.backend.model.send(@dataset_type, locale)
      end

      # Adds translation content to the XML builder.
      #
      # Handles both regular translations and array translations. For arrays,
      # retrieves all indexed elements (e.g., "key.0", "key.1") and outputs
      # each as a separate <translation> element.
      #
      # @param translation [Object] translation record with key, locale, is_array properties
      # @return [void]
      def add_translation(translation)
        if translation.is_array
          I18n.backend.model.by_prefix(translation.key, translation.locale).sort {
            |element_a, element_b|
            index_from_key(element_a.key) <=> index_from_key(element_b.key)
          }.each {
            |element|
            add_content(element)
          }
        else
          add_content(translation)
        end
      end

      # Outputs a single <translation> element with CDATA or empty text.
      #
      # Uses CDATA sections for translations with content to preserve special
      # characters and whitespace. Empty translations are output as empty elements.
      #
      # @param translation [Object] translation record with translation property
      # @return [void]
      def add_content(translation)
        @builder.translation {
          if translation.translation.present?
            @builder.cdata translation.translation
          else
            @builder.text ''
          end
        }
      end

      # Retrieves the reference translation for a given key.
      #
      # Uses lazy-loaded caching to minimize database queries. All reference
      # translations are loaded once on first access and stored in memory.
      #
      # @param key [String] the translation key to look up
      # @return [Object, nil] the reference translation record or nil if not found
      def get_reference(key)
        if @references.empty?
          I18n.backend.model.where(locale: @ref_locale).each {|ref|
            @references[ref.key] = ref
          }
        end
        @references[key]
      end

      # Extracts the numeric index from an array element key.
      #
      # @param key [String] key in format "base.key.0", "base.key.1", etc.
      # @return [Integer] the numeric index (e.g., 0, 1, 2)
      #
      # @example
      #   index_from_key("date.day_names.3")  #=> 3
      def index_from_key(key)
        key[key.rindex(".") + 1..-1].to_i
      end

    end

    # Helper class that exports locale metadata to XML format.
    #
    # Generates the <locales> section containing metadata for each locale such as
    # text direction (RTL/LTR), font preferences, and locale display names.
    #
    # @api private
    # @see XML#export
    class XMLLocales
      # Initializes the locale metadata exporter.
      #
      # @param builder [Nokogiri::XML::Builder] the XML builder instance
      def initialize(builder)
        @builder = builder
      end

      # Adds locale metadata for the specified locales to the XML.
      #
      # Creates a <locales> element containing <locale> entries with text direction,
      # font, and name for each locale. Metadata is retrieved from the database via
      # the locale_model.
      #
      # @param locales [Array<Symbol>] locales to export metadata for
      # @return [void]
      #
      # @example Generated XML structure
      #   <locales>
      #     <locale code="ar">
      #       <dir>rtl</dir>
      #       <font>Arial</font>
      #       <name>العربية</name>
      #     </locale>
      #   </locales>
      def add(locales)
        @builder.locales {
          locales.each do |locale|
            meta = get_meta(locale, locales)
            @builder.locale(code: locale) {
              @builder.dir (meta.rtl?) ? 'rtl' : 'ltr'
              @builder.font meta.font
              @builder.name meta.name
            }
          end
        }
      end

      private

      # Retrieves locale metadata from the database or returns empty metadata.
      #
      # Uses lazy-loaded lookup table to minimize database queries.
      #
      # @param locale [Symbol] the locale to retrieve metadata for
      # @param locales [Array<Symbol>] all locales being exported (for batch loading)
      # @return [Object] locale metadata record or new empty instance
      def get_meta(locale, locales)
        @meta_lookup ||= init_meta_lookup(locales)
        @meta_lookup.fetch(locale) do
          I18n.backend.locale_model.new
        end
      end

      # Initializes the locale metadata lookup hash.
      #
      # Performs a single database query to load all locale metadata at once.
      #
      # @param locales [Array<Symbol>] locales to load metadata for
      # @return [Hash{Symbol => Object}] hash mapping locale codes to metadata records
      def init_meta_lookup(locales)
        Hash[I18n.backend.locale_model.where(locale: locales).map {|l|
          [l.locale.to_sym, l]
        }]
      end
    end

    # Raised when attempting to export a locale that is not available.
    #
    # This exception indicates that one or more specified locales in the export
    # configuration do not exist in I18n.available_locales or I18n.system_locale.
    #
    # @example
    #   exporter = I18nLite::Exporter::XML.new
    #   exporter.locales = [:invalid_locale]
    #   exporter.export  #=> raises UnknownLocaleError
    class UnknownLocaleError < Exception
    end

    # Raised when an invalid dataset type is specified.
    #
    # Valid dataset types are :existing (all translated strings) and :untranslated
    # (keys with empty translations).
    #
    # @example
    #   exporter = I18nLite::Exporter::XML.new
    #   exporter.export(:invalid_type)  #=> raises UnknownDatasetError
    class UnknownDatasetError < Exception
    end

    # Raised when reference locale is missing (currently unused).
    #
    # This exception is defined but not currently raised by any code in the exporter.
    # May be reserved for future validation of reference locale presence.
    class NoReferenceLocaleError < Exception
    end
  end
end

# EXAMPLE FORMAT (AS EXPORTED):
#
# <?xml version="1.0" encoding="utf-8"?>
# <i18n generated="2014-05-17T13:10Z+02:00" version="v2.15">
#   <locales>
#     <locale code="sv">
#       <dir>ltr</dir>
#       <font>Arial</font>
#       <name>Svenska</name>
#     </locale>
#   </locales>
#   <strings locale="sv" reference-locale="system">
#     <string key="date.day_names">
#       <translation>Söndag</translation>
#       <translation>Måndag</translation>
#       <translation>Tisdag</translation>
#       <translation>Onsdag</translation>
#       <translation>Torsdag</translation>
#       <translation>Fredag</translation>
#       <translation>Lördag</translation>
#       <reference>
#         <translation>Sunday</translation>
#         <translation>Monday</translation>
#         <translation>Tueday</translation>
#         <translation>Wednesday</translation>
#         <translation>Thursday</translation>
#         <translation>Friday</translation>
#         <translation>Saturday</translation>
#       <reference>
#     </string>
#     <string key="mailer.coach_approves.notify_coach_new_waiting_message.body">
#       <translation><![CDATA[
#           Hej %{coach_first_name},
#
#           %{participant_name}, för vem du är coach, har klarmarkerat en uppgift som kräver ditt godkännande.
#           Du kan välja att godkänna uppgiften, eller att efterfråga ytterligare information från deltagaren.
#
#           För att se %{participant_first_name_s} svar för uppgiften "%{activity_title}", följ följande länk:
#           %{activity_url}
#       ]]></translation>
#       <reference>
#         <translation><![CDATA[
#           Hello %{coach_first_name},
#
#           %{participant_name}, for whom you are coach, has completed an assignment that requires your approval.
#           You can choose to approve the assignment or request additional information.
#
#           To review the %{participant_first_name_s} answer for the assignment "%{activity_title}", please follow this link:
#           %{activity_url}
#       ]]></translation>
#       <reference>
#     </string>
#   </strings>
# </i18n>
#
# EXAMPLE FORMAT (SIMPLE):
# <?xml version="1.0" encoding="utf-8"?>
# <i18n>
#   <strings locale="sv">
#     <string key="date.day_names">
#       <translation>Söndag</translation>
#       <translation>Måndag</translation>
#       <translation>Tisdag</translation>
#       <translation>Onsdag</translation>
#       <translation>Torsdag</translation>
#       <translation>Fredag</translation>
#       <translation>Lördag</translation>
#     </string>
#     <string key="mailer.coach_approves.notify_coach_new_waiting_message.body">
#       <translation><![CDATA[
#           Hej %{coach_first_name},
#
#           %{participant_name}, för vem du är coach, har klarmarkerat en uppgift som kräver ditt godkännande.
#           Du kan välja att godkänna uppgiften, eller att efterfråga ytterligare information från deltagaren.
#
#           För att se %{participant_first_name_s} svar för uppgiften "%{activity_title}", följ följande länk:
#           %{activity_url}
#       ]]></translation>
#     </string>
#   </strings>
# </i18n>
#
