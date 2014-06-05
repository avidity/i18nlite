require "spec_helper"

describe "I18nLite#with_locale" do

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

  context :with_locale do
    it { I18nLite.respond_to?(:with_locale).should be_true }

    it "support setting a temporary program_locale" do

      I18nLite.with_locale([:pt_BR, :fi, :en]) do
        I18n.locale.should == :pt_BR
        I18n.fallback_list.should == [:pt_BR, :fi, :en, :system]
      end

      I18n.locale.should == :de
      I18n.fallback_list.should == [:de, :system]
    end

    it "accepts a single symbol as locale argument" do
      I18nLite.with_locale(:pt_BR) do
        I18n.locale.should == :pt_BR
        I18n.fallback_list.should == [:pt_BR, :system]
      end

      I18n.locale.should == :de
      I18n.fallback_list.should == [:de, :system]
    end

    it "switches back to original locale in the event of an exception" do
      expect {
        I18nLite.with_locale([:sv]) do
          raise Exception.new
        end
      }.to raise_error(Exception)

      I18n.locale.should == :de
      I18n.fallback_list.should == [:de, :system]
    end

    it "returns the value of the last statement of the block" do

      locale = I18nLite.with_locale([:sv]) do
        I18n.locale
      end
      locale.should == :sv

      I18n.locale.should == :de
      I18n.fallback_list.should == [:de, :system]
    end
  end
end
