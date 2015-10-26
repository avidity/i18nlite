require "spec_helper"

describe I18nLite::Backend::SimpleImporter do
  it { is_expected.to be_kind_of I18n::Backend::Simple }

  before(:each) do
    allow(I18n).to receive(:load_path).and_return([File.join(File.dirname(__FILE__), '..', '..', 'support', 'data', 'sample.yml')])
    allow(I18n).to receive(:locale).and_return(:test_locale)
  end

  context '#all_flattened' do
    it 'provides a flattened hash of system locales' do
      backend = I18nLite::Backend::SimpleImporter.new

      expect(backend.all_flattened).to eq ({
        :"my.key"   => "My Key",
        :"my.other" => "My Other",
        :array      => [ "Zero", "One", "Two", "Three" ]
      })
    end

    it 'accepts a custom locale' do
      backend = I18nLite::Backend::SimpleImporter.new

      expect(backend.all_flattened(:my_locale)).to eq ({
        :"my.key"   => "My Key (my_locale)",
        :"my.other" => "My Other (my_locale)",
      })
    end
  end
end
