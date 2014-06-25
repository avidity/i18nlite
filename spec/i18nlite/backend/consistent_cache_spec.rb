require 'murmurhash3'
require "spec_helper"

class MyBackend
  include I18nLite::Backend::ConsistentCache
end

describe I18nLite::Backend::ConsistentCache do

  let(:backend) { MyBackend.new }

  it "implements I18n::Backend::Cache" do
    expect(backend).to be_kind_of(I18n::Backend::Cache)
  end

  it "returns a reversable cache key" do
    expect(backend.cache_key(
      :sv, :'my.translation.key', { interpolation: 'values', other: 'thing' }
    )).to eq "i18n/sv/my.translation.key/#{MurmurHash3::V32.str_hash("values;thing")}"

    expect(backend.cache_key(
      :sv, :'my.translation.key', {}
    )).to eq "i18n/sv/my.translation.key/"
  end
end
