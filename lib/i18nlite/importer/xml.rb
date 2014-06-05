require 'nokogiri'

module I18nLite
  module Importer
    class XML
      def initialize(xml)
        @doc = Nokogiri::XML(xml)
      end

      def import!
        @doc.xpath("//strings").each do |element|
          locale = element.attribute('locale').value

          import_locale(locale, element.xpath('./string'))
        end
      end

      private

      def import_locale(locale, elements)

        translations = {}

        elements.each do |element|
          key = element.attribute('key').value
          translation_values = element.xpath('./translation/text()')

          translations[key] = if translation_values.size == 1
            translation_values.first.to_s
          else
            translation_values.map {|v| v.to_s }
          end
        end

        I18n.store_translations(locale, translations)
      end
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
