require 'murmurhash3'
require "spec_helper"

class MyBackend
  include I18nLite::Backend::ConsistentCache
end

describe I18nLite::Backend::ConsistentCache do

  let(:backend) { MyBackend.new }

  before(:each) do
    I18n.stub(:system_locale).and_return(:system)
  end

  it "implements I18n::Backend::Cache" do
    expect(backend).to be_kind_of(I18n::Backend::Cache)
  end

  it "returns a reversable cache key" do
    expect(backend.cache_key(
      :sv, :'my.translation.key', { interpolation: 'values', other: 'thing' }
    )).to eq "i18n/;sv;system;/my.translation.key/#{MurmurHash3::V32.str_hash("values;thing")}"

    expect(backend.cache_key(
      :sv, :'my.translation.key', {}
    )).to eq "i18n/;sv;system;/my.translation.key/"
  end

  it 'returns configured fallback chain' do
    I18n.stub(:locale).and_return(:'sv-fi')
    I18n.fallback_list = [:'sv-se', :sv]

    expect(backend.cache_key(
      I18n.locale, :'my.key', {},
    )).to eq 'i18n/;sv-fi;sv-se;sv;system;/my.key/'
  end

  it 'uses locale unless fallback_list method is implemented' do
    I18n.stub(:respond_to?).with(:fallback_list).and_return(false)

    expect(backend.cache_key(
      :sv, :'my.translation.key', {}
    )).to eq "i18n/;sv;/my.translation.key/"
  end
end
