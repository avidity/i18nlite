# encoding: UTF-8
require "spec_helper"
require 'nokogiri'

describe I18nLite::Exporter::XML do
  def parse(xml)
    Nokogiri::XML(xml) { |c|
      c.strict
    }
  end

  before(:all) do
    I18n.backend = I18nLite::Backend::DB.new(TestTranslation)
  end

  before(:each) do
    I18n.stub(:available_locales).and_return([:pt, :sv, :en])
    I18n.stub(:system_locale).and_return(:system)
  end

  let(:exporter) { I18nLite::Exporter::XML.new() }

  context 'accessors' do
    it 'provides a default for #version' do
      expect(exporter.version).to eq "I18nLite v#{I18nLite::VERSION}"
    end

    it 'provides a default for #locales' do
      expect(exporter.locales).to eq([:pt, :sv, :en])
    end

    it 'provides a default for #ref_locale' do
      expect(exporter.ref_locale).to eq :system
    end

    it 'forces #locales to array of symbols' do
      exporter.locales = 'sv'
      expect(exporter.locales).to eq [:sv]
    end
  end

  context 'export' do
    it 'will check locales against available locales' do
      exporter.locales = [:en, :is]
      expect { exporter.export }.to raise_error(I18nLite::Exporter::UnknownLocaleError)
    end

    it 'will check ref_locale against available locales' do
      exporter.ref_locale = :is
      expect { exporter.export }.to raise_error(I18nLite::Exporter::UnknownLocaleError)
    end
  end

  context 'datasets' do
    before(:each) do
      exporter.locales = :en
    end
    it 'defaults to the existing dataset' do
      expect(I18n.backend.model).to receive(:existing).with(:en).and_call_original
      exporter.export
    end

    it 'supports the existing dataset' do
      expect {
        exporter.export(:existing)
      }.not_to raise_error
    end

    it 'supports the untranslated dataset' do
      expect {
        exporter.export(:untranslated)
      }.not_to raise_error
    end

    it 'requires an implemented dataset' do
      expect {
        exporter.export(:_invalid_)
      }.to raise_error(I18nLite::Exporter::UnknownDatasetError)
    end
  end

  context 'untranslated dataset' do
    before(:each) do
      exporter.locales = :en
      exporter.ref_locale = :system
    end

    it 'exports translations only in reference locale' do
      I18n.backend.store_translations(:system, {
        'my.key.a' => 'my key a system',
        'my.key.b' => 'my key b system',
        'my.key.c' => 'my key c system',
      })
      I18n.backend.store_translations(:en, {
        'my.key.a' => 'my key a en',
      })

      xml = exporter.export(:untranslated)

      expect(xml).not_to have_translation('en', 'my.key.a', 'my key a en')
      expect(xml).to have_translation('en', 'my.key.b', '')
      expect(xml).to have_reference('en', 'my.key.b', 'my key b system')
      expect(xml).to have_translation('en', 'my.key.c', '')
      expect(xml).to have_reference('en', 'my.key.c', 'my key c system')
    end
  end

  context '/i18n' do
    it 'exports current date' do
      date = "2014-06-25T09:12:12Z-0300"
      I18nLite::Exporter::XML.any_instance.stub(:get_date).and_return(date)

      xml = exporter.export
      expect(xml).to have_xml("/i18n[@generated='#{date}']")
    end

    it 'exports current version' do
      exporter.version = 'MyApp 1.0'
      xml = exporter.export
      expect(xml).to have_xml("/i18n[@version='MyApp 1.0']")
    end
  end

  context '//strings' do
    it 'export includes each locale separately' do
      exporter.locales = [:en, :sv]

      xml = exporter.export
      expect(xml).to have_xml('//strings[@locale="en"]')
      expect(xml).to have_xml('//strings[@locale="sv"]')
    end

    it 'includes reference locale in each strings tag' do
      exporter.locales = [:en, :sv]
      exporter.ref_locale = :pt

      xml = exporter.export
      expect(xml).to have_xml('//strings[@locale="en"][@reference-locale="pt"]')
      expect(xml).to have_xml('//strings[@locale="sv"][@reference-locale="pt"]')
    end

  end


  context '//translation' do
    before(:each) do
      I18n.backend.store_translations(:system, {
        'my.key.a' => 'my key a system',
        'my.key.b' => 'my key b system',
        'my.key.c' => 'my key c system',
        'my.array' => ['first system', 'second system', 'third system'],
      })
      I18n.backend.store_translations(:en, {
        'my.key.a' => 'my key a en',
        'my.key.b' => 'my key b en',
        'my.array' => ['first en', 'second en', 'third en'],
      })
      I18n.backend.store_translations(:sv, {
        'my.key.a' => 'my key a sv',
        'my.key.c' => 'my key c sv',
      })
    end

    it 'wraps translation content in cdata elements' do
      exporter.locales = :en
      xml = exporter.export
      doc = Nokogiri::XML(xml)

      expect(
        doc.xpath("//strings[@locale='en']/string[@key='my.key.a']/translation/text()").first
      ).to be_kind_of(Nokogiri::XML::CDATA)
    end

    it 'wrapes does not use cdata for empty elements' do
      I18n.backend.store_translations(:en, {
        'my.key.a' => ''
      })

      exporter.locales = :en
      xml = exporter.export
      doc = Nokogiri::XML(xml)

      expect(
        doc.xpath("//strings[@locale='en']/string[@key='my.key.a']/translation/text()").first
      ).to be_nil
    end

    it 'includes translations and references for given locales' do
      exporter.locales = [:en, :sv]
      xml = exporter.export

      expect(xml).to have_translation('en', 'my.key.a', 'my key a en')
      expect(xml).to have_translation('en', 'my.key.b', 'my key b en')
      expect(xml).to have_reference('en', 'my.key.a', 'my key a system')
      expect(xml).to have_reference('en', 'my.key.b', 'my key b system')

      expect(xml).to have_translation('sv', 'my.key.a', 'my key a sv')
      expect(xml).to have_translation('sv', 'my.key.c', 'my key c sv')
      expect(xml).to have_reference('sv', 'my.key.a', 'my key a system')
      expect(xml).to have_reference('sv', 'my.key.c', 'my key c system')

      expect(xml).not_to have_translation('sv', 'my.key.b', 'my key b sv')
      expect(xml).not_to have_reference('sv', 'my.key.b', 'my key b system')
      expect(xml).not_to have_translation('en', 'my.key.c', 'my key c en')
      expect(xml).not_to have_reference('en', 'my.key.c', 'my key c system')
    end

    it 'generates multiple translation in order for arrays' do
      exporter.locales = :en
      xml = exporter.export

      expect(xml).to have_translation_at('en', 'my.array', 1, 'first en')
      expect(xml).to have_translation_at('en', 'my.array', 2, 'second en')
      expect(xml).to have_translation_at('en', 'my.array', 3, 'third en')

      expect(xml).to have_reference_at('en', 'my.array', 1, 'first system')
      expect(xml).to have_reference_at('en', 'my.array', 2, 'second system')
      expect(xml).to have_reference_at('en', 'my.array', 3, 'third system')
    end

    it 'skips translations that does not exist in reference locale' do
      exporter.locales = :en
      exporter.ref_locale = :sv

      xml = exporter.export

      expect(xml).to have_translation('en', 'my.key.a', 'my key a en')
      expect(xml).to have_reference('en', 'my.key.a', 'my key a sv')

      expect(xml).not_to have_translation('en', 'my.key.b', 'my key b en')
      expect(xml).not_to have_translation('en', 'my.key.c', 'my key c en')
    end

    it 'does not include reference locale if reference is same as locale' do
      exporter.locales = :en
      exporter.ref_locale = :en

      xml = exporter.export

      expect(xml).to have_xml('//strings[@locale="en"]')
      expect(xml).not_to have_xml('//strings[@locale="en"][@reference-locale="en"]')
      expect(xml).to have_translation('en', 'my.key.a', 'my key a en')
      expect(xml).not_to have_reference('en', 'my.key.a', 'my key a en')
    end
  end
end


{
  translation: "//strings[@locale='%s']/string[@key='%s']/translation",
  reference: "//strings[@locale='%s']/string[@key='%s']/reference/translation",
  translation_at: "//strings[@locale='%s']/string[@key='%s']/translation[%i]",
  reference_at: "//strings[@locale='%s']/string[@key='%s']/reference/translation[%i]",
}.each_pair do |name, xpath|
  RSpec::Matchers.define :"have_#{name}" do |*args, text|

    path =  "#{args[0]}.#{args[1]}"
    path << "[#{args[2]}]" if name.to_s.ends_with?('_at')
    path << "=#{text}"
    desc = if name =~ /reference/
      'reference translation'
    else
      'reference'
    end

    match do |xml|
      expect(xml).to have_xml(sprintf(xpath, *args), text)
    end

    failure_message_for_should do |xml|
      "expected to find #{desc} #{path} in:\n#{xml}"
    end

    failure_message_for_should_not do |xml|
      "expected not to find #{desc} #{path} in:\n#{xml}"
    end

    description do
      "have #{desc} tag #{path}"
    end
  end
end
