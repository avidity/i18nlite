require 'nokogiri'

module I18nLite
  module Importer
    class XML
      def initialize(xml)
        @doc = Nokogiri::XML(xml) { |c|
          c.strict
        }

        validate!
      end

      def import!
        imported = {}

        @doc.xpath("//strings").each do |element|
          locale = element.attribute('locale').value

          imported[locale] = import_locale(locale, element.xpath('./string'))
        end

        return imported
      end

      private

      def validate!
        # FIXME: Perhaps we should just use a DTD instead? Or is that too much 1999?
        raise XMLFormatError.new('invalid root tag, expected i18n') unless @doc.root.name == 'i18n'
        raise XMLFormatError.new('require at least one string set to import') if @doc.xpath('//strings').count == 0
        raise XMLFormatError.new('strings tag requires locale attribute') if @doc.xpath('//strings[not(@locale)]').count > 0
        raise XMLFormatError.new('string tag requires key attribute') if @doc.xpath('//string[not(@key)]').count > 0
        raise XMLFormatError.new('string tag at least one translation child') if @doc.xpath('//string[not(translation)]').count > 0
        true
      end

      def import_locale(locale, elements)

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

        I18n.backend.store_translations(locale, translations)
      end
    end


    class Error < Exception
    end

    class XMLFormatError < Error
    end

    class ReferenceMismatchError < Error
    end
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
