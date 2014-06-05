require "spec_helper"

describe I18n do
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
