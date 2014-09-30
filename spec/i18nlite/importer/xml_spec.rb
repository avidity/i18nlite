# encoding: UTF-8
require "spec_helper"

describe I18nLite::Importer::XMLFormatError do
  it { is_expected.to be_kind_of(I18nLite::Importer::Error) }
end

describe I18nLite::Importer::ReferenceMismatchError do
  it { is_expected.to be_kind_of(I18nLite::Importer::Error) }
end

describe I18nLite::Importer::XML do
  def xml(name)
    TestXmlData.get(name)
  end

  context 'parse xml' do
    it 'throws an exception if xml is invalid' do
      expect {
        I18nLite::Importer::XML.new('not xml')
      }.to raise_error(Nokogiri::XML::SyntaxError)
    end
  end

  context 'xml format validation' do
    it 'requires the i18n root tag' do
      expect {
        I18nLite::Importer::XML.new(xml(:missing_root))
      }.to raise_error(I18nLite::Importer::XMLFormatError)
    end

    it 'requires the at least one strings tag' do
      expect {
        I18nLite::Importer::XML.new(xml(:missing_strings))
      }.to raise_error(I18nLite::Importer::XMLFormatError)
    end

    it 'strings tags requires a locale' do
      expect {
        I18nLite::Importer::XML.new(xml(:missing_locale))
      }.to raise_error(I18nLite::Importer::XMLFormatError)
    end

    it 'string tags requires a key' do
      expect {
        I18nLite::Importer::XML.new(xml(:missing_key))
      }.to raise_error(I18nLite::Importer::XMLFormatError)
    end

    it 'string tags requires at least one translation child' do
      expect {
        I18nLite::Importer::XML.new(xml(:missing_translation))
      }.to raise_error(I18nLite::Importer::XMLFormatError)
    end
  end

  context 'parsing' do
    it 'imports each locale separately' do
      importer = I18nLite::Importer::XML.new(xml(:two_locales))

      expect(importer).to receive(:import_locale).with('sv', anything())
      expect(importer).to receive(:import_locale).with('en', anything())
      importer.import!
    end

    it 'invokes I18n#store_translations once per locale' do
      importer = I18nLite::Importer::XML.new(xml(:three_strings))

      expect(I18n.backend).to receive(:store_translations).with('sv', {
        'site.welcome' => 'Välkommen',
        'site.bye' => 'Hejdå',
        'site.welcome_back' => 'Välkommen tillbaka'
      })
      importer.import!
    end

    it 'handles cdata sections correctly' do
      importer = I18nLite::Importer::XML.new(xml(:cdata))

      expect(I18n.backend).to receive(:store_translations).with('sv', {
        'site.welcome' => 'Välkommen <b>hit</b>!'
      })
      importer.import!
    end

    it 'accepts empty elements as non-null empty translations' do
      importer = I18nLite::Importer::XML.new(xml(:empty_element))

      expect(I18n.backend).to receive(:store_translations).with('sv', {
        'site.welcome' => ''
      })

      importer.import!
    end
  end

  context 'parse array values' do
    it 'supports arrays of strings' do
      importer = I18nLite::Importer::XML.new(xml(:array))

      expect(I18n.backend).to receive(:store_translations).with('sv', {
        'site.things' => ['En', 'Två', 'Tre']
      })
      importer.import!
    end

    it 'accepts empty array elements as non-null empty translations' do
      importer = I18nLite::Importer::XML.new(xml(:empty_array_element))

      expect(I18n.backend).to receive(:store_translations).with('sv', {
        'site.welcome' => ['', 'En', 'Två']
      })

      importer.import!
    end

    it 'forces locale to be lower case' do
      importer = I18nLite::Importer::XML.new(xml(:upper_case_locale))

      expect(I18n.backend).to receive(:store_translations).with('sv-se', {
        'site.welcome' => 'Välkommen'
      })

      importer.import!
    end

    it 'requires translations to be array if reference is' do
      importer = I18nLite::Importer::XML.new(xml(:no_array))

      expect {
        importer.import!
      }.to raise_error(I18nLite::Importer::ReferenceMismatchError)
    end

    it 'requires number of translation elements to match reference elements' do
      importer = I18nLite::Importer::XML.new(xml(:uneven_array))

      expect {
        importer.import!
      }.to raise_error(I18nLite::Importer::ReferenceMismatchError)
    end

    it 'will not accept array unless reference is one' do
      importer = I18nLite::Importer::XML.new(xml(:should_not_be_array))

      expect {
        importer.import!
      }.to raise_error(I18nLite::Importer::ReferenceMismatchError)
    end
  end

  context 'returns' do
    it 'a hash with imported locales and numbers' do
      importer = I18nLite::Importer::XML.new(xml(:two_locales))

      expect(importer).to receive(:import_locale).with('sv', anything()).and_return(10)
      expect(importer).to receive(:import_locale).with('en', anything()).and_return(5)

      expect(importer.import!).to eq({
        'sv' => 10,
        'en' => 5
      })
    end
  end
end


module TestXmlData
  @xml = {

    array: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.things">
            <translation>En</translation>
            <translation>Två</translation>
            <translation>Tre</translation>
          </string>
        </strings>
      </i18n>
eoXML

    three_strings: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation>Välkommen</translation>
          </string>
          <string key="site.bye">
            <translation>Hejdå</translation>
          </string>
          <string key="site.welcome_back">
            <translation>Välkommen tillbaka</translation>
          </string>
        </strings>
      </i18n>
eoXML
    simple: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation>Välkommen</translation>
          </string>
        </strings>
      </i18n>
eoXML
    cdata: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation><![CDATA[Välkommen <b>hit</b>!]]></translation>
          </string>
        </strings>
      </i18n>
eoXML
    two_locales: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation>Välkommen</translation>
          </string>
        </strings>
        <strings locale="en">
          <string key="site.welcome">
            <translation>Welcome</translation>
          </string>
        </strings>
      </i18n>
eoXML
    missing_root: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <strings locale="sv">
        <string key="site.welcome">
          <translation>Välkommen</translation>
        </string>
      </strings>
eoXML
    missing_strings: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
      </i18n>
eoXML
    missing_locale: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings>
          <string key="site.welcome">
            <translation>Välkommen</translation>
          </string>
        </strings>
      </i18n>
eoXML
    upper_case_locale: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv-SE">
          <string key="site.welcome">
            <translation>Välkommen</translation>
          </string>
        </strings>
      </i18n>
eoXML
    missing_key: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string>
            <translation>Välkommen</translation>
          </string>
        </strings>
      </i18n>
eoXML
    empty_element: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation/>
          </string>
        </strings>
      </i18n>
eoXML
    empty_array_element: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation/>
            <translation>En</translation>
            <translation>Två</translation>
          </string>
        </strings>
      </i18n>
eoXML
    no_array: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation>Hej</translation>
            <reference>
              <translation>Hi</translation>
              <translation>Hello</translation>
            </reference>
          </string>
        </strings>
      </i18n>
eoXML
    uneven_array: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation>Hej</translation>
            <translation>Tjena</translation>
            <reference>
              <translation>Hi</translation>
              <translation>Hello</translation>
              <translation>Yo</translation>
            </reference>
          </string>
        </strings>
      </i18n>
eoXML
    should_not_be_array: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
            <translation>Hej</translation>
            <translation>Tjena</translation>
            <reference>
              <translation>Hi</translation>
            </reference>
          </string>
        </strings>
      </i18n>
eoXML
    missing_translation: <<'eoXML',
      <?xml version="1.0" encoding="utf-8"?>
      <i18n>
        <strings locale="sv">
          <string key="site.welcome">
          </string>
        </strings>
      </i18n>
eoXML
  }

  def self.get(name)
    return @xml.fetch(name).gsub(/^\s{6}/, '')
  end
end
