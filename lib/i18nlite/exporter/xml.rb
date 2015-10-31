require 'nokogiri'
require 'date'
require 'i18nlite/version'


module I18nLite
  module Exporter
    class XML

      attr_accessor :version, :ref_locale, :locales

      def initialize
      end

      def version
        @version ||= "I18nLite v#{I18nLite::VERSION}"
      end

      def ref_locale
        @ref_locale ||= I18n.system_locale
      end

      def locales
        @locales ||= I18n.available_locales || []
      end

      def locales=(locales)
        @locales = Array(locales).map(&:to_sym)
      end

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

      def get_date
        DateTime.now.iso8601
      end
    end


    class XMLTranslations
      def initialize(builder, ref_locale, dataset_type)
        unless [:untranslated, :existing].include? dataset_type
          raise UnknownDatasetError.new(dataset_type)
        end

        @builder = builder
        @ref_locale = ref_locale
        @dataset_type = dataset_type
        @references = {}
      end

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

      def include_reference?(locale)
        locale != @ref_locale
      end

      def dataset(locale)
        I18n.backend.model.send(@dataset_type, locale)
      end

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

      def add_content(translation)
        @builder.translation {
          if translation.translation.present?
            @builder.cdata translation.translation
          else
            @builder.text ''
          end
        }
      end

      def get_reference(key)
        if @references.empty?
          I18n.backend.model.where(locale: @ref_locale).each {|ref|
            @references[ref.key] = ref
          }
        end
        @references[key]
      end

      def index_from_key(key)
        key[key.rindex(".") + 1..-1].to_i
      end

    end

    class XMLLocales
      def initialize(builder)
        @builder = builder
      end

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

      def get_meta(locale, locales)
        @meta_lookup ||= init_meta_lookup(locales)
        @meta_lookup.fetch(locale) do
          I18n.backend.locale_model.new
        end
      end

      def init_meta_lookup(locales)
        Hash[I18n.backend.locale_model.where(locale: locales).map {|l|
          [l.locale.to_sym, l]
        }]
      end
    end

    class UnknownLocaleError < Exception
    end

    class UnknownDatasetError < Exception
    end

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
