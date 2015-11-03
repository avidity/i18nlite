require 'nokogiri'

module I18nLite
  module Importer
    class XML
      attr_accessor :imported

      def initialize(xml)
        @imported = {}
        @doc = Nokogiri::XML(xml) { |c|
          c.strict
        }

        validate!
      end

      def import!
        import_locale_meta if I18n.backend.kind_of? I18nLite::Backend::DB
        import_translations

        imported
      end


      def import_translations
        @doc.xpath("//strings").each do |element|
          locale = element.attribute('locale').value.downcase
          import_translation_elements(locale, element.xpath('./string'))
        end
      end

      def import_locale_meta
        @doc.xpath('//locales/locale').each do |element|
          import_meta_element(element)
        end
      end

      private

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

      def import_meta_element(element)
        locale = I18n.backend.locale_model.new
        locale.locale = element.attribute('code').value

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


    class Error < StandardError; end
    class TextDirectionError < Error; end
    class UnknownLocaleAttribute < Error; end
    class XMLFormatError < Error; end
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
#           To review the %{participant_first_name_s} answer for the assignment ”%{activity_title}”, please follow this link:
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
