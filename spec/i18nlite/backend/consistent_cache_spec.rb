require 'murmurhash3'
require "spec_helper"

class MyBackend
  include I18nLite::Backend::ConsistentCache
end

describe I18nLite::Backend::ConsistentCache do

  let(:backend) { MyBackend.new }

  it "implements I18n::Backend::Cache" do
    backend.should be_kind_of(I18n::Backend::Cache)
  end

  it "returns a reversable cache key" do
    backend.cache_key(
      :sv, :'my.translation.key', { interpolation: 'values', other: 'thing' }
    ).should == "i18n/sv/my.translation.key/#{MurmurHash3::V32.str_hash("values;thing")}"

    backend.cache_key(
      :sv, :'my.translation.key', {}
    ).should == "i18n/sv/my.translation.key/"
  end
end
