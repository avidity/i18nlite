require "spec_helper"

describe I18nLite::Error do
  before(:each) do
    @default_handler = I18n.exception_handler
  end

  after(:each) do
    I18n.exception_handler = @default_handler
  end
  describe "RaiseMissingHandler" do
    it 'raises an exception when encoutering a missing translation' do
      I18n.exception_handler = I18nLite::Error::RaiseMissingHandler.new

      expect(I18n.exception_handler).to receive(:call).and_call_original
      expect {
        I18n.t('__no_such_key__')
      }.to raise_error(I18n::MissingTranslationData)
    end
  end

  describe "RegisterMissingHandler" do
    before(:each) do
      I18n.exception_handler = I18nLite::Error::RegisterMissingHandler.new
    end

    it 'raises an exception when encoutering a missing translation' do
      expect(I18n.exception_handler).to receive(:call).and_call_original
      expect {
        I18n.t('__no_such_key__')
      }.to raise_error(I18n::MissingTranslationData)
    end

    it 'raises an exception through Promote::ExceptionReporter if it exists' do
      stub_const("Promote::ExceptionReporter", double)
      expect(I18n.exception_handler).to receive(:call).and_call_original
      expect(Promote::ExceptionReporter).to receive(:rescue_and_report).with(/^Translation missing/)
      I18n.t('__no_such_key__')
    end
  end


end
