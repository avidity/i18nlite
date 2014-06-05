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
      I18nLite::CacheControl.respond_to?(:can_clear_keys?).should be_true
    end

    it "can clear keys if cache store is a memory store" do
      I18n.stub(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      I18nLite::CacheControl.can_clear_keys?.should be_true
    end

    it "cannot clear keys if cache store is the base store" do
      I18n.stub(:cache_store) { MyTest::FakeCacheStore.new }
      I18nLite::CacheControl.can_clear_keys?.should be_false
    end
  end

  context "adaptor" do
    it "finds adaptor based on I18n cache setting" do
      I18n.stub(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      I18nLite::CacheControl.adaptor.should be_kind_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end
  end

  context "clear by key" do
    let(:key1) { "Key 1" }
    let(:key2) { "Key 2" }

    it "calls the adaptor to get a pattern matching each key" do
      I18n.stub(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      I18nLite::CacheControl.adaptor.should_receive(:scoped_pattern).with(key1)
      I18nLite::CacheControl.adaptor.should_receive(:scoped_pattern).with(key2)
      I18nLite::CacheControl.clear_keys(key1, key2)
    end

    it "It defaults to invoking clear of the configured cache store" do
      cache = MyTest::FakeCacheStore.new
      cache.should_receive(:clear)
      I18n.stub(:cache_store) { cache }
      I18nLite::CacheControl.clear_keys(key1, key2)
    end
  end

  context "clear all" do
    it "calls the adaptor to get a pattern matching all i18n keys" do
      I18n.stub(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
      I18nLite::CacheControl.adaptor.should_receive(:greedy_pattern)
      I18nLite::CacheControl.clear_all
    end

    it "It defaults to invoking clear of the configured cache store" do
      cache = MyTest::FakeCacheStore.new
      cache.should_receive(:clear)
      I18n.stub(:cache_store) { cache }
      I18nLite::CacheControl.clear_all
    end
  end
end

describe I18nLite::KeyedCacheAdaptor::Base do
  subject { I18nLite::KeyedCacheAdaptor::Base }

  context "instantiation" do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    it "returns an adaptor suitable to the give store" do
      subject.adaptor_for( store  ).should be_instance_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end

    it "caches the result for each class" do
      subject.adaptor_for( store  ).should == subject.adaptor_for( store  )
      subject.adaptor_for( store  ).should_not == subject.adaptor_for( ActiveSupport::Cache::NullStore.new  )
    end

    it "returns instance of base class if no suitable adaptor is found" do
      subject.adaptor_for( MyTest::FakeCacheStore.new  ).should be_instance_of( subject )
    end
  end

  context "RegExp store" do
    it "handles MemoryStore" do
      subject.adaptor_for( ActiveSupport::Cache::MemoryStore.new  ).should be_instance_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end

    it "handles FileStore" do
      subject.adaptor_for( ActiveSupport::Cache::FileStore.new('temp')  ).should be_instance_of( I18nLite::KeyedCacheAdaptor::RegExp )
    end
  end
end
