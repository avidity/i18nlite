require "spec_helper"

module MyOriginalNamespace
  class << self
    include I18nLite::Compat

    def compat_delegate_to
      MyNewImplementation
    end
  end
end

class MyOriginalClass
  class << self
    include I18nLite::Compat

    def compat_delegate_to
      MyNewClass
    end
  end
end

module MyNewImplementation
  class << self
    def some_method
      return :something
    end

    def method_with_args(arg1, arg2)
    end

    def method_with_block(&block)
      yield block
    end
  end
end

class MyNewClass
  def self.my_class_method
  end
end

describe I18nLite::Compat do
  before(:each) do
    allow_message_expectations_on_nil
    Rails.logger.stub(:info)
  end

  it 'forwards calls to configured new interface' do
    expect(MyNewImplementation).to receive(:some_method)
    MyOriginalNamespace.some_method
  end

  it 'only forwards existing methods' do
    expect {
      MyOriginalNamespace.undefined_method
    }.to raise_error(NoMethodError)
  end

  it 'forwards arguments' do
    expect(MyNewImplementation).to receive(:method_with_args).with(:first, :second)
    MyOriginalNamespace.method_with_args(:first, :second)
  end

  it 'forwards blocks' do
    expect(
      MyOriginalNamespace.method_with_block do
        "hej"
      end
    ).to eq("hej")
  end

  it 'logs a deprication message' do
    expect(Rails.logger).to receive(:info).with(/MyOriginalNamespace#some_method .+ MyNewImplementation#some_method.+called at.+compat_spec.rb:\d+:in `.+/)
    MyOriginalNamespace.some_method
  end
end

describe PromoteI18n::CacheControl do
  it { is_expected.to be_a I18nLite::Compat }
  it 'should delegate to I18nLite' do
    expect(PromoteI18n::CacheControl.compat_delegate_to).to be I18nLite::CacheControl
  end
end

describe PromoteI18n do
  it { is_expected.to be_a I18nLite::Compat }
  it 'should delegate to I18nLite' do
    expect(PromoteI18n.compat_delegate_to).to be I18nLite
  end
end

describe PromoteI18n::RaiseTranslationMissingHandler do
  it { is_expected.to be_a I18nLite::Compat }
  it 'should delegate to I18nLite' do
    expect(PromoteI18n::RaiseTranslationMissingHandler.compat_delegate_to).to be I18nLite::Error::RaiseMissingHandler
  end
end

