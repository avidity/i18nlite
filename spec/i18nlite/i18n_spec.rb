require "spec_helper"

describe I18n do

  after(:each) do
    I18n.class_variable_set(:'@@fallback_list', {})
  end

  it 'adds a new fallback_list property to I18n' do
    expect(I18n.fallback_list).to be_an(Array)
  end

  it 'adds an immutable system locale' do
    expect(I18n.system_locale).to be :system
  end

  describe 'meta' do
    context 'with other backend' do
      it 'returns empty hash' do
        expect(I18n.meta).to eq({})
      end
    end

    context 'with I18Lite::Backend::DB' do
      before(:each) do
        @backend = I18n.backend
        @locale  = I18n.locale

        I18n.backend = I18nLite::Backend::DB.new(TestTranslation)
        I18n.locale = :dummy
      end

      after(:each) do
        I18n.backend = @backend
        I18n.locale  = @locale
      end

      it 'returns meta property of associated LocaleModel object' do
        locale_object = TestLocale.create(locale: I18n.locale, font: 'Arial', rtl: true)
        expect(I18n.meta).to eq locale_object.meta
      end

      it 'returns empty hash if matching locale is not found' do
        expect(I18n.meta).to eq({})
      end
    end
  end

  context "fallback_list" do
    it 'will automatically include locale in fallback chain' do
      expect(I18n.fallback_list.first).to eq(I18n.locale)
    end

    it 'will automatically include configured system locale at the bottom' do
      expect(I18n.fallback_list.last).to eq(I18n.system_locale)
    end

    it 'treat a nil fallback_list as an empty array' do
      I18n.fallback_list = nil
      expect(I18n.fallback_list).to eq [I18n.locale, I18n.system_locale]
    end

    it 'treat a non-array fallback_list as an empty array' do
      I18n.fallback_list = "blah"
      expect(I18n.fallback_list).to eq [I18n.locale, I18n.system_locale]
    end

    it 'adds all elements to current fallback' do
      I18n.fallback_list = [:fallback_1, :fallback_2]
      expect(I18n.fallback_list).to eq [I18n.locale, :fallback_1, :fallback_2, I18n.system_locale]
    end

    it 'will store fallbacks independent on current locale' do
      allow(I18n).to receive(:locale).and_return(:sv)
      I18n.fallback_list = [:fallback_sv]
      allow(I18n).to receive(:locale).and_return(:en)

      expect(I18n.fallback_list).to eq [:en, I18n.system_locale]
    end

    it 'will accept a specific locale to retrieve fallback' do
      expect(I18n.fallback_list(:my_locale)).to eq [:my_locale, I18n.system_locale]
      expect(I18n.fallback_list).to eq [I18n.locale, I18n.system_locale]
    end
  end
end
