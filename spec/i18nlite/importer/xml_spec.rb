# encoding: UTF-8
require "spec_helper"

describe I18nLite::Importer::XML do
  def xml(name)
    TestXmlData.get(name)
  end

  context 'scan xml' do
    it 'imports each locale separately' do
      importer = I18nLite::Importer::XML.new(xml(:two_locales))

      importer.should_receive(:import_locale).with('sv', anything())
      importer.should_receive(:import_locale).with('en', anything())
      importer.import!
    end

    it 'invokes I18n#store_translations once per locale' do
      importer = I18nLite::Importer::XML.new(xml(:three_strings))

      I18n.should_receive(:store_translations).with('sv', {
        'site.welcome' => 'Välkommen',
        'site.bye' => 'Hejdå',
        'site.welcome_back' => 'Välkommen tillbaka'
      })
      importer.import!
    end

    it 'supports arrays of strings' do
      importer = I18nLite::Importer::XML.new(xml(:array))

      I18n.should_receive(:store_translations).with('sv', {
        'site.things' => ['En', 'Två', 'Tre']
      })
      importer.import!
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
  }

  def self.get(name)
    return @xml.fetch(name).gsub(/^\s{6}/, '')
  end
end
