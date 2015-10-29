require "spec_helper"

# TestTranslation is defined in spec/active_record_helper.rb

describe TestLocale do
  it { is_expected.to be_kind_of I18nLite::ActiveRecord::LocaleModel }

  context 'has many translations' do
    subject { TestLocale.create(locale: 'dummy') }
    before(:each) do
      TestTranslation.create(locale: subject.locale, key: 'key1')
      TestTranslation.create(locale: subject.locale, key: 'key2')
      TestTranslation.create(locale: 'dummy2', key: 'key2')
    end

    it 'relationship exists' do
      expect( subject.translations.map(&:key) ).to contain_exactly('key1', 'key2')
    end

    it 'is dependent destroy' do
      expect {
        subject.destroy
      }.to change {
        TestTranslation.count
      }.by(-2)
    end
  end

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


  context '#meta' do
    subject { TestLocale.new(locale: 'dummy', font: 'Arial', rtl: true ) }

    it 'is a hash of all meta properties' do
      expect( subject.meta ).to eq({
        font: 'Arial',
        rtl: true,
        ltr: false,
        direction: 'RTL'
      })
    end

    it 'returns correct values when rtl is false' do
      subject.rtl = false
      expect( subject.meta ).to eq({
        font: 'Arial',
        rtl: false,
        ltr: true,
        direction: 'LTR'
      })
    end
  end

  describe 'text direction' do
    subject { TestLocale.new(locale: 'dummy') }

    context 'property rtl' do
      it 'defaults to false' do
        expect( subject.rtl? ).to be false
      end

      it 'can be set to true' do
        subject.rtl = true
        expect( subject ).to be_rtl
      end
    end

    context 'property ltr' do
      it 'defaults to true' do
        expect( subject.ltr? ).to be true
      end

      it 'is inverse of rtl' do
        expect( subject.ltr? ).to be !subject.rtl?
      end

      it 'is false if rtl is true' do
        subject.rtl = true
        expect( subject ).to_not be_ltr
      end

      it 'can be used to set inverse of rtl' do
        subject.ltr = false
        expect( subject ).to be_rtl
        expect( subject.rtl).to be true
      end
    end

    context 'property direction' do
      it 'returns HTML friendly string when ltr' do
        subject.rtl = false
        expect( subject.direction ).to eq 'LTR'
      end

      it 'returns HTML friendly string when rtl' do
        subject.rtl = true
        expect( subject.direction ).to eq 'RTL'
      end
    end

  end
end
