require 'nokogiri'

module I18nLite
  module Importer
    # Imports internationalization data from XML format into I18n backend storage.
    #
    # This importer parses XML documents containing translation strings and optional
    # locale metadata, validates the structure, and stores the data using the
    # configured I18n backend. The importer supports both single-value translations
    # and multi-value translations (stored as arrays).
    #
    # @note The import process is NOT atomic. Validation occurs during initialization,
    #   but import operations are not transactional. If an import fails midway,
    #   partial data may already be stored in the backend.
    #
    # @note Locale metadata import only occurs when using {I18nLite::Backend::DB}.
    #   Translation import works with any I18n backend.
    #
    # @example Importing translations from XML
    #   xml_content = File.read('translations.xml')
    #   importer = I18nLite::Importer::XML.new(xml_content)
    #   results = importer.import!
    #   # => { "en" => {...}, "sv" => {...} }
    #
    # @example XML format with single translation
    #   <?xml version="1.0" encoding="utf-8"?>
    #   <i18n>
    #     <strings locale="en">
    #       <string key="hello">
    #         <translation>Hello, World!</translation>
    #       </string>
    #     </strings>
    #   </i18n>
    #
    # @example XML format with array translation
    #   <?xml version="1.0" encoding="utf-8"?>
    #   <i18n>
    #     <strings locale="en">
    #       <string key="date.day_names">
    #         <translation>Sunday</translation>
    #         <translation>Monday</translation>
    #         <translation>Tuesday</translation>
    #       </string>
    #     </strings>
    #   </i18n>
    #
    # @example XML format with locale metadata
    #   <?xml version="1.0" encoding="utf-8"?>
    #   <i18n>
    #     <locales>
    #       <locale code="ar">
    #         <dir>rtl</dir>
    #         <name>Arabic</name>
    #       </locale>
    #     </locales>
    #     <strings locale="ar">
    #       <string key="hello">
    #         <translation>مرحبا</translation>
    #       </string>
    #     </strings>
    #   </i18n>
    #
    # @see I18nLite::Exporter::XML
    class XML
      # Hash mapping locale codes (strings) to backend-specific import results.
      # The structure of values depends on the I18n backend implementation's
      # return value from `store_translations`.
      #
      # @return [Hash{String => Object}] locale code to import result mapping
      attr_accessor :imported

      # Creates a new XML importer and validates the XML structure.
      #
      # Parses the provided XML using Nokogiri in strict mode and performs
      # structural validation to ensure required elements and attributes are
      # present. This does not perform the actual import - call {#import!} to
      # import the data.
      #
      # @param xml [String] XML document content to import
      #
      # @raise [XMLFormatError] if XML structure is invalid:
      #   - Root element is not 'i18n'
      #   - No 'strings' elements found
      #   - 'strings' element missing 'locale' attribute
      #   - 'string' element missing 'key' attribute
      #   - 'string' element has no 'translation' child elements
      #   - 'locale' element missing 'code' attribute (when locales present)
      #
      # @raise [Nokogiri::XML::SyntaxError] if XML is malformed
      #
      # @example
      #   xml = '<i18n><strings locale="en"><string key="test"><translation>Test</translation></string></strings></i18n>'
      #   importer = I18nLite::Importer::XML.new(xml)
      def initialize(xml)
        @imported = {}
        @doc = Nokogiri::XML(xml) { |c|
          c.strict
        }

        validate!
      end

      # Imports translations and locale metadata from the XML document.
      #
      # Performs the actual import operation by:
      # 1. Importing locale metadata (if using {I18nLite::Backend::DB})
      # 2. Importing all translation strings
      #
      # @note Locale metadata is only imported when the I18n backend is
      #   {I18nLite::Backend::DB}. Translations are imported regardless of
      #   backend type.
      #
      # @return [Hash{String => Object}] mapping of locale codes to the return
      #   values from `I18n.backend.store_translations` for each locale. The
      #   structure of values is backend-dependent.
      #
      # @raise [TextDirectionError] if locale metadata contains invalid text direction
      # @raise [UnknownLocaleAttribute] if locale metadata contains unsupported attributes
      # @raise [ReferenceMismatchError] if translation/reference count mismatch
      #
      # @example
      #   importer = I18nLite::Importer::XML.new(xml_content)
      #   results = importer.import!
      #   # => { "en" => {...}, "sv" => {...} }
      def import!
        import_locale_meta if I18n.backend.kind_of? I18nLite::Backend::DB
        import_translations

        imported
      end


      # Imports translation strings from all `<strings>` elements.
      #
      # Processes each `<strings>` element in the XML document, extracting the
      # locale and delegating to {#import_translation_elements} for the actual
      # translation import. Multiple `<translation>` elements under a single
      # `<string>` are combined into an array and passed to the backend.
      #
      # @note When multiple `<translation>` elements exist for a key, they are
      #   stored as a Ruby array. The backend receives this array via
      #   `store_translations(locale, {key => array})`. How the backend persists
      #   arrays is implementation-dependent.
      #
      # @note Empty translations are valid. A `<translation></translation>` element
      #   with no content is acceptable and will be imported as an empty string.
      #
      # @return [void]
      #
      # @example Single translation
      #   # <string key="hello"><translation>Hello</translation></string>
      #   # Imports: { "hello" => "Hello" }
      #
      # @example Array translation
      #   # <string key="days">
      #   #   <translation>Monday</translation>
      #   #   <translation>Tuesday</translation>
      #   # </string>
      #   # Imports: { "days" => ["Monday", "Tuesday"] }
      def import_translations
        @doc.xpath("//strings").each do |element|
          locale = element.attribute('locale').value.downcase
          import_translation_elements(locale, element.xpath('./string'))
        end
      end

      # Imports locale metadata from all `<locale>` elements.
      #
      # Processes each `<locale>` element in the XML document, creating or updating
      # locale records in the database with metadata attributes. The `<dir>` element
      # is special-cased and converted to a boolean `rtl` attribute on the model.
      #
      # @note This method only executes when using {I18nLite::Backend::DB}. Call
      #   {#import!} which conditionally invokes this method based on backend type.
      #
      # @note Supported attributes depend on the locale model's database schema.
      #   Attributes are set dynamically using `attribute=` if they exist on the model.
      #
      # @return [void]
      #
      # @raise [TextDirectionError] if `<dir>` contains value other than 'rtl', 'ltr', or empty
      # @raise [UnknownLocaleAttribute] if XML contains element for non-existent model attribute
      #
      # @example
      #   # <locale code="ar">
      #   #   <dir>rtl</dir>
      #   #   <name>Arabic</name>
      #   # </locale>
      #   # Creates/updates locale with: locale="ar", rtl=true, name="Arabic"
      def import_locale_meta
        @doc.xpath('//locales/locale').each do |element|
          import_meta_element(element)
        end
      end

      private

      # Validates XML document structure before import.
      #
      # Ensures all required elements and attributes are present and properly
      # structured. This validation occurs during initialization, before any
      # import operations.
      #
      # @return [true] if validation passes
      #
      # @raise [XMLFormatError] with descriptive message if validation fails
      def validate!
        # FIXME: Perhaps we should just use a DTD instead? Or is that too much 1999?
        raise XMLFormatError.new('invalid root tag, expected i18n') unless @doc.root.name == 'i18n'
        raise XMLFormatError.new('require at least one string set to import') if @doc.xpath('//strings').count == 0
        raise XMLFormatError.new('strings tag requires locale attribute') if @doc.xpath('//strings[not(@locale)]').count > 0
        raise XMLFormatError.new('string tag requires key attribute') if @doc.xpath('//string[not(@key)]').count > 0
        raise XMLFormatError.new('string tag at least one translation child') if @doc.xpath('//string[not(translation)]').count > 0

        if @doc.xpath('//locales/locale').count > 0
          raise XMLFormatError.new('locale element requires code attribute') if @doc.xpath('//locale[not(@code)]').count > 0
        end

        true
      end

      # Imports metadata for a single locale from a `<locale>` XML element.
      #
      # Creates or updates a locale record with attributes from child elements.
      # The `<dir>` element is converted to a boolean `rtl` attribute (true for 'rtl',
      # false for 'ltr' or empty). Other child elements are mapped directly to model
      # attributes if they exist.
      #
      # @param element [Nokogiri::XML::Element] the `<locale>` element to process
      #
      # @return [void]
      #
      # @raise [TextDirectionError] if `<dir>` value is not 'rtl', 'ltr', or empty
      # @raise [UnknownLocaleAttribute] if element name doesn't match a model attribute
      def import_meta_element(element)
        code = element.attribute('code').value
        locale = I18n.backend.locale_model.find_or_create_by(locale: code)

        if dir = element.xpath('./dir/text()').to_s
          raise TextDirectionError.new("unknown text direction #{dir}") unless dir =~ /^(rtl|ltr|)$/i
          locale.rtl = dir.downcase == 'rtl'
        end

        element.element_children.each do |child|
          next if child.name == 'dir'
          raise UnknownLocaleAttribute.new(child.name) unless locale.has_attribute?(child.name)
          locale.send(:"#{child.name}=", child.content)
        end

        locale.save!
      end

      # Imports translation strings for a single locale.
      #
      # Processes a collection of `<string>` elements, extracting keys and translation
      # values. When a `<string>` contains multiple `<translation>` elements, they are
      # combined into an array. Validates reference counts if `<reference>` elements
      # are present.
      #
      # @param locale [String] the locale code for these translations
      # @param elements [Nokogiri::XML::NodeSet] collection of `<string>` elements
      #
      # @return [void]
      #
      # @raise [ReferenceMismatchError] if number of `<translation>` elements doesn't
      #   match number of `<reference><translation>` elements
      def import_translation_elements(locale, elements)
        translations = {}

        elements.each do |element|
          key = element.attribute('key').value
          translation_elements = element.xpath('./translation')

          translation = if translation_elements.size == 1
            translation_elements.first.content
          else
            translation_elements.map {|v| v.content }
          end

          num_references = element.xpath('count(./reference/translation)').to_i

          if num_references > 0
            num_translated = (translation.kind_of?(Array)) ? translation.size : 1

            unless num_references == num_translated
              raise ReferenceMismatchError.new("#{key} has #{num_translated} translations, expected #{num_references}")
            end
          end

          translations[key] = translation
        end

        @imported[locale] = I18n.backend.store_translations(locale, translations)
      end
    end


    # Base error class for all importer-related errors.
    class Error < StandardError; end

    # Raised when locale metadata contains an invalid text direction value.
    #
    # Valid values are 'rtl' (right-to-left), 'ltr' (left-to-right), or empty string.
    class TextDirectionError < Error; end

    # Raised when locale metadata contains an attribute that doesn't exist on the locale model.
    #
    # This occurs when the XML contains a child element under `<locale>` that doesn't
    # correspond to a database column or attribute on the locale model.
    class UnknownLocaleAttribute < Error; end

    # Raised when XML document structure is invalid or missing required elements.
    #
    # This error is raised during initialization if the XML doesn't conform to the
    # expected schema (e.g., missing required attributes, wrong root element).
    class XMLFormatError < Error; end

    # Raised when translation count doesn't match reference translation count.
    #
    # This occurs when a `<string>` element has `<reference>` elements, but the
    # number of `<reference><translation>` elements doesn't equal the number of
    # `<translation>` elements.
    class ReferenceMismatchError < Error; end
  end
end

# EXAMPLE FORMAT (AS EXPORTED):
#
# <?xml version="1.0" encoding="utf-8"?>
# <i18n generated="2014-05-17T13:10Z+02:00" version="v2.15">
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
