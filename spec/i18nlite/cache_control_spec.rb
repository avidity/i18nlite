require "spec_helper"

module MyTest
  class FakeCacheStore < ActiveSupport::Cache::Store
    def clear
    end
  end
end

describe I18nLite::CacheControl do
  context "can_clear_keys? method" do
    it "supports checking whether a keyed cache storage is present" do
      expect(I18nLite::CacheControl.respond_to?(:can_clear_keys?)).to be true
    end

    it "can clear keys if cache store is a memory store" do
      allow(I18n).to receive(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      expect(I18nLite::CacheControl.can_clear_keys?).to be true
    end

    it "cannot clear keys if cache store is the base store" do
      allow(I18n).to receive(:cache_store) { MyTest::FakeCacheStore.new }
      expect(I18nLite::CacheControl.can_clear_keys?).to be false
    end
  end

  context "adaptor" do
    it "finds adaptor based on I18n cache setting" do
      allow(I18n).to receive(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      expect(I18nLite::CacheControl.adaptor).to be_kind_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end
  end

  context "clear by key" do
    let(:key1) { "Key 1" }
    let(:key2) { "Key 2" }

    it "calls the adaptor to get a pattern matching each key" do
      allow(I18n).to receive(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      expect(I18nLite::CacheControl.adaptor).to receive(:scoped_pattern).with(key1)
      expect(I18nLite::CacheControl.adaptor).to receive(:scoped_pattern).with(key2)
      I18nLite::CacheControl.clear_keys(key1, key2)
    end

    it "It defaults to invoking clear of the configured cache store" do
      cache = MyTest::FakeCacheStore.new
      expect(cache).to receive(:clear)
      allow(I18n).to receive(:cache_store) { cache }
      I18nLite::CacheControl.clear_keys(key1, key2)
    end
  end

  context "clear all" do
    it "calls the adaptor to get a pattern matching all i18n keys" do
      allow(I18n).to receive(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      expect(I18nLite::CacheControl.adaptor).to receive(:greedy_pattern)
      I18nLite::CacheControl.clear_all
    end

    it "It defaults to invoking clear of the configured cache store" do
      cache = MyTest::FakeCacheStore.new
      expect(cache).to receive(:clear)
      allow(I18n).to receive(:cache_store) { cache }
      I18nLite::CacheControl.clear_all
    end
  end

  context "clear locale" do
    it "calls the adaptor to get a pattern matching all i18n keys for a locale" do
      allow(I18n).to receive(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      expect(I18nLite::CacheControl.adaptor).to receive(:locale_pattern).with(:en)
      I18nLite::CacheControl.clear_locale(:en)
    end

    it "It defaults to invoking clear of the configured cache store" do
      cache = MyTest::FakeCacheStore.new
      expect(cache).to receive(:clear)
      allow(I18n).to receive(:cache_store) { cache }
      I18nLite::CacheControl.clear_locale(:en)
    end
  end
end

describe I18nLite::KeyedCacheAdaptor::Base do
  subject { I18nLite::KeyedCacheAdaptor::Base }

  context "instantiation" do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    it "returns an adaptor suitable to the give store" do
      expect(subject.adaptor_for( store  )).to be_instance_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end

    it "caches the result for each class" do
      expect(subject.adaptor_for( store )).to eq subject.adaptor_for( store )
      expect(subject.adaptor_for( store )).not_to eq subject.adaptor_for( ActiveSupport::Cache::NullStore.new )
    end

    it "returns instance of base class if no suitable adaptor is found" do
      expect(subject.adaptor_for( MyTest::FakeCacheStore.new )).to be_instance_of( subject )
    end
  end

  context "Redis store" do
    context 'with Rails 7.1 RedisStore' do
      before do
        # It'll run this test if the class doesn't exist (Rails 8+)
        skip "RedisStore exists in this Rails version" if defined?(
          ActiveSupport::Cache::RedisStore
        )

        # Mock the RedisStore class for Rails 8 testing
        stub_const('ActiveSupport::Cache::RedisStore', Class.new)
      end

      it 'returns Redis adaptor for RedisStore' do
        store = ActiveSupport::Cache::RedisStore.new

        expect(subject.adaptor_for(store)).to be_instance_of(
          I18nLite::KeyedCacheAdaptor::Redis
        )
      end
    end

    context 'with Rails 8 RedisCacheStore' do
      it 'returns Redis adaptor for RedisCacheStore' do
        store = ActiveSupport::Cache::RedisCacheStore.new

        expect(subject.adaptor_for(store)).to be_instance_of(
          I18nLite::KeyedCacheAdaptor::Redis
        )
      end
    end
  end

  context "RegExp store" do
    it "handles MemoryStore" do
      expect(subject.adaptor_for( ActiveSupport::Cache::MemoryStore.new )).to be_instance_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end

    it "handles FileStore" do
      expect(subject.adaptor_for( ActiveSupport::Cache::FileStore.new('temp') )).to be_instance_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end
  end
end
