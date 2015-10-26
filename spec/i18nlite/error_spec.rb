require "spec_helper"


describe I18nLite::Error::RaiseMissingHandler do

  before(:each) do
    @default_handler = I18n.exception_handler
    I18n.exception_handler = subject
  end

  after(:each) do
    I18n.exception_handler = @default_handler
  end

  it 'invokes #call' do
    expect(subject).to receive(:call)
    I18n.t('__no_such_key__')
  end

  it 'raises an exception' do
    expect {
      I18n.t('__no_such_key__')
    }.to raise_error(I18n::MissingTranslationData)
  end
end

