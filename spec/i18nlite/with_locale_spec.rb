require "spec_helper"

describe I18nLite do

  before :each do
    @original_fallbacks = I18n.fallback_list
    @original_locale    = I18n.locale

    I18n.fallback_list = []
    I18n.locale = :de
  end

  after :each do
    I18n.fallback_list = @original_fallback
    I18n.locale        = @original_locale
  end

  it { is_expected.to respond_to(:with_locale) }

  context :with_locale do
    it "support setting a temporary program_locale" do

      I18nLite.with_locale([:pt_BR, :fi, :en]) do
        expect(I18n.locale).to eq :pt_BR
        expect(I18n.fallback_list).to eq [:pt_BR, :fi, :en, :system]
      end

      expect(I18n.locale).to eq :de
      expect(I18n.fallback_list).to eq [:de, :system]
    end

    it "accepts a single symbol as locale argument" do
      I18nLite.with_locale(:pt_BR) do
        expect(I18n.locale).to eq :pt_BR
        expect(I18n.fallback_list).to eq [:pt_BR, :system]
      end

      expect(I18n.locale).to eq :de
      expect(I18n.fallback_list).to eq [:de, :system]
    end

    it "switches back to original locale in the event of an exception" do
      expect {
        I18nLite.with_locale([:sv]) do
          raise Exception.new
        end
      }.to raise_error(Exception)

      expect(I18n.locale).to eq :de
      expect(I18n.fallback_list).to eq [:de, :system]
    end

    it "returns the value of the last statement of the block" do

      locale = I18nLite.with_locale([:sv]) do
        I18n.locale
      end
      expect(locale).to eq :sv

      expect(I18n.locale).to eq :de
      expect(I18n.fallback_list).to eq [:de, :system]
    end
  end
end
