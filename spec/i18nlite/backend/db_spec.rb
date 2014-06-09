require "spec_helper"

describe I18nLite::Backend::DB do

  before(:each) do
    @original_backend = I18n.backend
    @original_locale  = I18n.locale

    I18n.enforce_available_locales = false
    I18n.backend = I18nLite::Backend::DB.new(TestTranslation)
    I18n.locale = :system
  end

  after(:each) do
    I18n.enforce_available_locales = true
    I18n.backend = @original_backend
    I18n.locale  = @original_locale
  end

  it 'should have correct interfaces' do
    expect(I18n.backend).to be_an(I18n::Backend::Base)
    expect(I18n.backend).to be_an(I18n::Backend::Flatten)
    expect(I18n.backend).to be_an(I18nLite::Backend::ConsistentCache)
    expect(I18n.backend.model).to be(TestTranslation)
  end

  context "Used as backend" do
    it "receives calls via I18n interface" do
      the_key = :'translation.key'
      expect_any_instance_of(I18nLite::Backend::DB).to receive(:lookup).with(anything, the_key, anything, anything)
      I18n.t(the_key)
    end
  end

  context "available locales" do
    it "automatically adds :en to list of available locales" do
      TestTranslation.create(locale: 'dummy', key: 'dummy')

      expect(TestTranslation).to receive(:all_locales).and_call_original
      expect(I18n.available_locales).to eq [:en, :dummy]
    end
    it "includes en only if its not already in the list" do
      TestTranslation.create(locale: 'en')

      expect(I18n.available_locales).to eq [:en]
    end
  end

  context "lookup" do
    it "finds a translation in the database" do
      the_translation = 'This is in dummian'
      TestTranslation.create(locale: 'system', key: 'dummy.key', translation: the_translation)

      expect(I18n.t(:'dummy.key')).to eq the_translation
    end

    it "triggers missing translation if key does not exist" do
      expect {
        I18n.t(:'dummy.key', raise: true)
      }.to raise_error(I18n::MissingTranslationData)
    end

    it "interpolates arguments" do
      TestTranslation.create(locale: 'system', key: 'dummy.key', translation: 'My name is %{name}!')

      expect(I18n.t(:'dummy.key', name: 'Gunnar')).to eq 'My name is Gunnar!'
    end

    it "does not support partial key lookup" do
      TestTranslation.create(locale: 'system', key: 'dummy.key', translation: 'First')

      expect {
        I18n.t(:dummy, raise: true)
      }.to raise_error(I18n::MissingTranslationData)
    end

    it 'can lookup a key given a scope' do
      the_translation = 'This is in dummian'
      TestTranslation.create(locale: 'system', key: 'scoped.dummy.key', translation: the_translation)

      expect(I18n.t(:key, scope: :'scoped.dummy')).to eq the_translation
    end
  end

  context 'lookup pluralization' do
    let(:one_translation)   { 'exactly one' }
    let(:other_translation) { 'other amount' }
    let(:none_translation) { 'nuffin' }

    before(:each) do
      TestTranslation.create(locale: 'system', key: 'how_many.one', translation: one_translation)
      TestTranslation.create(locale: 'system', key: 'how_many.other', translation: other_translation)
    end

    it 'returns correct value for count > 0' do
      expect(I18n.t(:'how_many', count: 10)).to eq other_translation
    end

    it 'returns correct value for count = 0' do
      expect(I18n.t(:'how_many', count: 0)).to eq other_translation
    end

    it 'returns correct value for count = 1' do
      expect(I18n.t(:'how_many', count: 1)).to eq one_translation
    end

    it 'supports the zero key' do
      TestTranslation.create(locale: 'system', key: 'how_many.zero', translation: none_translation)
      expect(I18n.t(:'how_many', count: 0)).to eq none_translation
    end

    it 'will yield missing translation if not found' do
      expect {
        I18n.t(:'doesnt.exist', count: 10, raise: true)
      }.to raise_error(I18n::MissingTranslationData)
    end

    it 'will yield missing translation sub keys are unsupported' do
      TestTranslation.create(locale: 'system', key: 'bad_format.what')
      expect {
        I18n.t(:'bad_format', count: 10)
      }.to raise_error(I18n::InvalidPluralizationData)
    end
  end

  context "lookup arrays" do
    before(:each) do
      TestTranslation.create(locale: 'system', key: 'dummy.key.1', translation: 'Second')
      TestTranslation.create(locale: 'system', key: 'dummy.key.0', translation: 'First')
      TestTranslation.create(locale: 'system', key: 'dummy.key.2', translation: 'Third')
      TestTranslation.create(locale: 'system', key: 'dummy.key', translation: nil, is_array: true)
    end

    it "identifies an array of values by index" do
      expect(I18n.t(:'dummy.key')).to eq ['First', 'Second', 'Third']
    end

    it "returns an array index key as is" do
      expect(I18n.t(:'dummy.key.1')).to eq 'Second'
    end

    it 'can lookup arrays using a scope' do
      expect(I18n.t(:key, scope: :dummy)).to eq ['First', 'Second', 'Third']
    end
  end

  context "storing" do
    it "can store a translation" do
      I18n.backend.store_translations(:system, :'new.key' => 'my translation')
      expect(I18n.t(:'new.key')).to eq('my translation')
    end

    it "can store multiple translations in one call" do
      I18n.backend.store_translations(:system, :'new.key' => 'my translation', :'other.new.key' => 'my other translation')
      expect(I18n.t(:'new.key')).to eq('my translation')
      expect(I18n.t(:'other.new.key')).to eq('my other translation')
    end

    it "is able to detect and store array values" do
      I18n.backend.store_translations(:system, :'new.key' => ['one', 'two', 'three'])

      expect(I18n.t(:'new.key')).to eq ['one', 'two', 'three']
      expect(I18n.t(:'new.key.0')).to eq 'one'
      expect(I18n.t(:'new.key.1')).to eq 'two'
      expect(I18n.t(:'new.key.2')).to eq 'three'
    end

    it 'supports nested data structure' do
      I18n.backend.store_translations(:system, {
        root: {
          first: 'My translation',
          nested: {
            first: 'Nested translation',
            second: 'Also a translation'
          }
        },
        also_root: 'Root!'
      })

      expect(I18n.t(:'root.first')).to eq('My translation')
      expect(I18n.t(:'root.nested.first')).to eq('Nested translation')
      expect(I18n.t(:'root.nested.second')).to eq('Also a translation')
      expect(I18n.t(:'also_root')).to eq('Root!')
    end
  end

  context 'I18n extensions' do
    it 'adds a new fallback_list property to I18n' do
      expect(I18n.fallback_list).to be_an(Array)
    end

    it 'adds an immutable system locale' do
      expect(I18n.system_locale).to be :system
    end

    context "fallback_list" do
      it 'will automatically include locale in fallback chain' do
        expect(I18n.fallback_list.first).to eq(I18n.locale)
      end

      it 'will automatically include configured system locale at the bottom' do
        expect(I18n.fallback_list.last).to eq(I18n.system_locale)
      end

      it 'treat a nil fallback_list as an arry' do
        I18n.fallback_list = nil
        expect(I18n.fallback_list).to be_an(Array)
      end

      it 'treat a non-array fallback_list as an empty array' do
        I18n.fallback_list = "blah"
        expect(I18n.fallback_list).to be_an(Array)
      end
    end
  end

  context 'lookup with fallbacks' do
    before(:each) do
      @original_fallbacks = I18n.fallback_list
      I18n.fallback_list = [:middle_locale]
      I18n.locale = :dummy
    end

    after(:each) do
      I18n.fallback_list = @original_fallbacks
    end

    it 'ensures current and system locale exists in fallback_list' do
      expect(I18n.fallback_list).to eq [:dummy, :middle_locale, :system]
    end

    it 'prefers top locale' do
      TestTranslation.create(locale: I18n.locale,    key: 'my.key', translation: 'In top')
      TestTranslation.create(locale: :middle_locale, key: 'my.key', translation: 'In middle')
      TestTranslation.create(locale: :system,        key: 'my.key', translation: 'In bottom')

      expect(I18n.t(:'my.key')).to eq('In top')
    end

    it 'drops down to middle locale' do
      TestTranslation.create(locale: :middle_locale, key: 'my.key', translation: 'In middle')
      TestTranslation.create(locale: :system, key: 'my.key', translation: 'In bottom')

      expect(I18n.t(:'my.key')).to eq('In middle')
    end

    it 'will try system locale last' do
      TestTranslation.create(locale: :system, key: 'my.key', translation: 'In bottom')

      expect(I18n.t(:'my.key')).to eq('In bottom')
    end

    it 'supports pluralization lookups with fallback' do
      TestTranslation.create(locale: :system, key: 'how_many.one', translation:   'En')
      TestTranslation.create(locale: :system, key: 'how_many.other', translation: 'Flera')
      TestTranslation.create(locale: :system, key: 'how_many.zero', translation: 'Inga')

      expect(I18n.t(:'how_many', count: 1)).to eq('En')
      expect(I18n.t(:'how_many', count: 2)).to eq('Flera')
      expect(I18n.t(:'how_many', count: 0)).to eq('Inga')
    end
  end
end
