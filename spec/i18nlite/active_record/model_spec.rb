require "spec_helper"

# TestTranslation is defined in spec/active_record_helper.rb

describe TestTranslation do
  it { is_expected.to be_kind_of I18nLite::ActiveRecord::Model }

  context '::all_locales' do
    it "retrieves an array of all locales" do
      TestTranslation.create(locale: 'dummy1', key: 'dummy.key')
      TestTranslation.create(locale: 'dummy2', key: 'dummy.key')
      TestTranslation.create(locale: 'dummy2', key: 'dummy.key2')

      expect( TestTranslation.all_locales ).to match_array(['dummy1', 'dummy2'])
    end
  end

  context '::by_prefix' do
    it 'retrieves an array of translations matches the prefix' do
      t1 = TestTranslation.create(locale: 'dummy1', key: 'dummy.key1')
      t2 = TestTranslation.create(locale: 'dummy1', key: 'dummy.key2')
      t3 = TestTranslation.create(locale: 'dummy1', key: 'other.key')

      expect( TestTranslation.by_prefix(:dummy, :dummy1) ).to match_array([t1, t2])
    end

    it 'sorts matching translations on their key' do
      t1 = TestTranslation.create(locale: 'dummy1', key: 'dummy.key.2')
      t2 = TestTranslation.create(locale: 'dummy1', key: 'dummy.key.0')
      t3 = TestTranslation.create(locale: 'dummy1', key: 'dummy.key.1')

      expect( TestTranslation.by_prefix(:dummy, :dummy1) ).to eq([t2, t3, t1])
    end
  end

  context '::find_by_preference' do
    it 'will return first matching locale' do
      t1 = TestTranslation.create(locale: 'preferred', key: 'my.key')
      t2 = TestTranslation.create(locale: 'fallback', key: 'my.key')

      expect(
        TestTranslation.by_preference('my.key', [:preferred, :fallback])
      ).to eq t1
    end

    it 'will drop by order of preference (choose second)' do
      t1 = TestTranslation.create(locale: 'second', key: 'my.key')
      t2 = TestTranslation.create(locale: 'fallback', key: 'my.key')

      expect(
        TestTranslation.by_preference('my.key', [:preferred, :second, :fallback])
      ).to eq t1
    end

    it 'will drop by order of preference (choose last)' do
      t1 = TestTranslation.create(locale: 'fallback', key: 'my.key')

      expect(
        TestTranslation.by_preference('my.key', [:preferred, :second, :fallback])
      ).to eq t1
    end

    it 'will only return matches for keys that exists for last fallback' do
      t1 = TestTranslation.create(locale: 'preferred', key: 'my.key')

      expect(
        TestTranslation.by_preference('my.key', [:preferred, :fallback])
      ).to be_nil
    end

    it 'performs simple query if only one locale is given' do
      expect(TestTranslation).to receive(:find_by).with(key: 'my.key', locale: 'a_locale')
      TestTranslation.by_preference('my.key', ['a_locale'])
    end
  end

  context '::find_by_preference!' do
    it 'behaves like find_by_preference if it finds a match' do
      t1 = TestTranslation.create(locale: 'preferred', key: 'my.key')
      t2 = TestTranslation.create(locale: 'fallback', key: 'my.key')

      expect(
        TestTranslation.by_preference!('my.key', [:preferred, :fallback])
      ).to eq t1
    end

    it 'raises RecordNotFound if no match can be found' do
      expect {
        TestTranslation.by_preference!('my.key', [:preferred, :fallback])
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context '::trim_to_universe' do
    before(:each) do
      TestTranslation.create(locale: 'my_locale', key: 'my.key')
      TestTranslation.create(locale: 'my_locale', key: 'my.other.key')
    end

    it 'removes all keys not present for the given key' do
      TestTranslation.create(locale: 'system', key: 'my.key')


      expect {
        TestTranslation.trim_to_universe(:system)
      }.to change {
        TestTranslation.count()
      }.from(3).to(2)

      expect( TestTranslation.find_by(key: 'my.other.key') ).to be_nil
    end

    it 'removes all keys if universe is empty' do
      expect {
        TestTranslation.trim_to_universe(:system)
      }.to change {
        TestTranslation.count()
      }.from(2).to(0)
    end

    it 'does nothing if there is nothing to be removed' do
      TestTranslation.create(locale: 'system', key: 'my.key')
      TestTranslation.create(locale: 'system', key: 'my.other.key')

      expect {
        TestTranslation.trim_to_universe(:system)
      }.not_to change {
        TestTranslation.count()
      }
    end
  end

  context '::all_by_preference' do

    before(:each) do
      @t1 = TestTranslation.create(locale: 'preferred', key: 'my.key')
      @t2 = TestTranslation.create(locale: 'fallback', key: 'fallback.only')
      @t3 = TestTranslation.create(locale: 'fallback', key: 'my.key')
    end

    it 'returns all matching records in the given universe' do

      # FIXME: Unsorted array comparison using expect...to syntax with rspec 2.14?
      TestTranslation.all_by_preference([:preferred, :fallback]).should =~ [@t1, @t2]
    end

    it 'ignores keys outside of universe' do
      t4 = TestTranslation.create(locale: 'preferred', key: 'outside.universe')

      # FIXME: Unsorted array comparison using expect...to syntax with rspec 2.14?
      TestTranslation.all_by_preference([:preferred, :fallback]).should =~ [@t1, @t2]
    end

    it 'performs single query if only one locale is given' do
      expect(TestTranslation).to receive(:find_by).with(locale: 'a_locale')
      TestTranslation.all_by_preference(['a_locale'])
    end

    it 'returns empty array on no hits (single locales)' do
      expect(
        TestTranslation.all_by_preference([:not_in_db])
      ).to be_empty
    end

    it 'returns empty array on no hits (multiple locales)' do
      expect(
        TestTranslation.all_by_preference([:preferred, :not_in_db])
      ).to be_empty
    end
  end

  context '::all_by_preference_fast' do
    before(:each) do
      TestTranslation.create(locale: 'preferred', key: 'my.key', translation: 'preferred translation (my.key)')
      TestTranslation.create(locale: 'fallback', key: 'fallback.only', translation: 'fallback translation (fallback.only)')
      TestTranslation.create(locale: 'fallback', key: 'my.key', translation: 'fallback translation (my.key)')
    end

    it 'returns hash of all translation in universe by best matching locale' do
      expect(
        TestTranslation.all_by_preference_fast([:preferred, :fallback])
      ).to eq({
        'my.key'        => 'preferred translation (my.key)',
        'fallback.only' => 'fallback translation (fallback.only)'
      })
    end

    it 'returns empty array on no hits' do
      expect(
        TestTranslation.all_by_preference_fast([:not_in_db])
      ).to be_empty
    end
  end

  context '::insert_filtered' do
    it 'inserts given locales' do
      expect {
        TestTranslation.insert_filtered([
          { locale: :system, key: 'my.key', translation: 'my translation' },
          { locale: :system, key: 'my.new', translation: 'new translation' },
        ])
      }.to change {
        TestTranslation.count()
      }.from(0).to(2)
    end

    it 'ignores existing key/value pairs' do
      TestTranslation.create({ locale: :system, key: 'my.key', translation: 'my translation' })
      expect {
        TestTranslation.insert_filtered([
          { locale: :system, key: 'my.key', translation: 'my other translation' },
          { locale: :system, key: 'my.new', translation: 'new translation' },
        ])
      }.to change {
        TestTranslation.count()
      }.from(1).to(2)

      expect(
        TestTranslation.find_by(locale: :system, key: 'my.key').translation
      ).to eq('my translation')
    end
  end
end
