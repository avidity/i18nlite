require "spec_helper"

# TestTranslation is defined in spec/active_record_helper.rb

describe TestLocale do
  it { is_expected.to be_kind_of I18nLite::ActiveRecord::LocaleModel }

  context '::insert_missing' do
    it 'creates entries for given locales' do
      expect {
        TestLocale.insert_missing('dummy1', 'dummy2')
      }.to change {
        TestLocale.all_locales
      }.from([])
       .to(['dummy1', 'dummy2'])
    end

    it 'ignores present locales' do
      TestLocale.create(locale: 'dummy1')
      expect {
        TestLocale.insert_missing('dummy1', 'dummy2')
      }.to change {
        TestLocale.all_locales
      }.from(['dummy1'])
       .to(['dummy1', 'dummy2'])
    end

    it 'accepts values as symobls' do
      TestLocale.create(locale: 'dummy1')
      expect {
        TestLocale.insert_missing(:dummy1, :dummy2)
      }.to change {
        TestLocale.count
      }.by(1)
    end

    it 'does nothing if locale already exists' do
      TestLocale.create(locale: 'dummy1')
      expect {
        TestLocale.insert_missing(:dummy1)
      }.not_to change {
        TestLocale.count
      }
    end
  end

  context '::all_locales' do

    it 'retrieves locale codes only, ordered' do
      TestLocale.create(locale: 'dummy1')
      TestLocale.create(locale: 'dummy3')
      TestLocale.create(locale: 'dummy2')

      expect( TestLocale.all_locales ).to eq ['dummy1', 'dummy2', 'dummy3']
    end

    it 'always returns an array' do
      TestLocale.create(locale: 'dummy2')

      expect( TestLocale.all_locales ).to eq ['dummy2']
    end
  end
end
