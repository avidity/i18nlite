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

      expect(backend.all_flattened).to eq({
        :"my.key" => "My Key",
        :"my.other" => "My Other",
        :array => %w(Zero One Two Three)
      })
    end

    it 'accepts a custom locale' do
      backend = I18nLite::Backend::SimpleImporter.new

      expect(backend.all_flattened(:my_locale)).to eq({
        :"my.key" => "My Key (my_locale)",
        :"my.other" => "My Other (my_locale)",
      })
    end
  end

  context '#load_translations' do
    let(:yml_locale_file) { File.join(File.dirname(__FILE__), '..', '..', 'support', 'data', 'sample.yml') }
    let(:rb_locale_file) { File.join(File.dirname(__FILE__), '..', '..', 'support', 'data', 'sample.rb') }

    before(:each) do
      allow(I18n).to receive(:load_path).and_return([
        yml_locale_file,
        rb_locale_file
      ])
    end

    it 'will not load the ruby file' do
      backend = I18nLite::Backend::SimpleImporter.new

      expect(backend.load_translations).to eq([yml_locale_file])
    end

    it 'returns a empty list if a ruby file was provided' do
      backend = I18nLite::Backend::SimpleImporter.new
      translations = backend.load_translations(
        rb_locale_file
      )

      expect(translations).to eq([])
    end

    it 'returns only the yml file path if a ruby and yml file was provided' do
      backend = I18nLite::Backend::SimpleImporter.new
      translations = backend.load_translations(
        rb_locale_file,
        yml_locale_file
      )

      expect(translations).to eq([yml_locale_file])
    end

    context "with a nested list of locales" do
      before(:each) do
        allow(I18n).to receive(:load_path).and_return([
          [yml_locale_file, rb_locale_file],
          rb_locale_file
        ])
      end

      it 'returns only the yml file path' do
        backend = I18nLite::Backend::SimpleImporter.new
        translations = backend.load_translations(
          rb_locale_file,
          yml_locale_file
        )

        expect(translations).to eq([yml_locale_file])
      end
    end
  end
end
