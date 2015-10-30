require 'murmurhash3'
require "spec_helper"

class MyBackend
  include I18nLite::Backend::ConsistentCache
end

describe I18nLite::Backend::ConsistentCache do

  subject { MyBackend.new }
  it { is_expected.to be_kind_of I18n::Backend::Cache }
  it { is_expected.to be_kind_of I18nLite::Backend::ConsistentCache }

  before(:each) do
    allow(I18n).to receive(:system_locale).and_return(:system)
  end

  context 'cache_key' do
    it "returns a reversable cache key" do
      expect(subject.cache_key(
        :sv, :'my.translation.key', { interpolation: 'values', other: 'thing' }
      )).to eq "i18n/;sv;system;/my.translation.key/#{MurmurHash3::V32.str_hash("values;thing")}"

      expect(subject.cache_key(
        :sv, :'my.translation.key', {}
      )).to eq "i18n/;sv;system;/my.translation.key/"
    end

    it 'returns configured fallback chain' do
      allow(I18n).to receive(:locale).and_return(:'sv-fi')
      I18n.fallback_list = [:'sv-se', :sv]

      expect(subject.cache_key(
        I18n.locale, :'my.key', {},
      )).to eq 'i18n/;sv-fi;sv-se;sv;system;/my.key/'
    end

    it 'uses locale unless fallback_list method is implemented' do
      allow(I18n).to receive(:respond_to?).with(:fallback_list).and_return(false)

      expect(subject.cache_key(
        :sv, :'my.translation.key', {}
      )).to eq "i18n/;sv;/my.translation.key/"
    end
  end

  context 'meta_cache_key' do
    it 'generatings cache key for given locale' do
      expect(subject.meta_cache_key(:sv)).to eq 'i18n/meta/sv'
    end
  end
end
