# encoding: UTF-8
require "spec_helper"

describe I18nLite::Importer::SimpleBackend do

  let(:locale)   { :target_locale }
  let(:importer) { I18nLite::Importer::SimpleBackend.new(TestTranslation, :test_locale, locale) }

  def translation_by_key(key)
    TestTranslation.find_by(key: key, locale: locale)
  end

  before(:each) do
    I18n.stub(:load_path).and_return([File.join(File.dirname(__FILE__), '..', '..', 'support', 'data', 'sample.yml')])
  end

  context 'initialization' do
    it 'requires a database model' do
      importer = I18nLite::Importer::SimpleBackend.new(TestTranslation, :my_src, :my_trg)
      expect(importer.instance_variable_get(:@database_model)).to be TestTranslation
    end

    it 'accepts source and target locales' do
      importer = I18nLite::Importer::SimpleBackend.new(TestTranslation, :my_src, :my_trg)

      expect(importer.instance_variable_get(:@source_locale)).to be :my_src
      expect(importer.instance_variable_get(:@target_locale)).to be :my_trg
    end

    it 'sets target locale to I18n.system_locale by default' do
      importer = I18nLite::Importer::SimpleBackend.new(TestTranslation, :my_src)

      expect(importer.instance_variable_get(:@source_locale)).to be :my_src
      expect(importer.instance_variable_get(:@target_locale)).to be I18n.system_locale
      expect(I18n.system_locale).to_not be_nil
    end
  end

  context 'importing' do
    it 'imports translations with target locale' do
      expect {
        importer.import!
      }.to change {
        TestTranslation.where(locale: locale).count
      }.from(0)
    end

    it 'can import arrays' do
      importer.import!

      expect(
        translation_by_key('array').is_array()
      ).to be true

      expect(
        TestTranslation.by_prefix('array', locale).map {|t| t.translation }
      ).to eq ['Zero', 'One', 'Two', 'Three']
    end

    it 'imports all keys' do
      importer.import!

      expect(
        TestTranslation.where(locale: locale).order(:key).map(&:key)
      ).to eq ['array', 'array.0', 'array.1', 'array.2', 'array.3', 'my.key', 'my.other']
    end

    it 'updates existing keys' do
      TestTranslation.create(locale: locale, key: 'my.key', translation: 'only in database')

      expect {
        importer.import!
      }.to change {
        translation_by_key('my.key').reload.translation
      }.from('only in database').to('My Key')
    end
  end

  context 'syncing' do
    it 'imports all keys' do
      importer.sync!

      expect(
        TestTranslation.where(locale: locale).order(:key).map(&:key)
      ).to eq ['array', 'array.0', 'array.1', 'array.2', 'array.3', 'my.key', 'my.other']
    end

    it 'deletes existing keys that is not in imported universe' do
      TestTranslation.create(locale: locale, key: 'my.special.key', translation: 'only in database')
      importer.sync!

      expect( translation_by_key('my.special.key') ).to be_nil
    end

    it 'overwrites existing translations' do
      TestTranslation.create(locale: locale, key: 'my.key', translation: 'only in database')

      expect {
        importer.sync!
      }.to change {
        translation_by_key('my.key').reload.translation
      }.from('only in database').to('My Key')
    end

    it 'ignores keys for other locales' do
      TestTranslation.create(locale: :my_locale, key: 'my.special.key', translation: 'only in database')
      TestTranslation.create(locale: :my_locale, key: 'my.key', translation: 'only in database')

      importer.sync!

      expect(TestTranslation.find_by(locale: :my_locale, key: 'my.special.key')).not_to be_nil
      expect(TestTranslation.find_by(locale: :my_locale, key: 'my.key')).not_to be_nil
    end
  end
end

