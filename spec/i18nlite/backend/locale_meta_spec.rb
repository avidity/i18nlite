require "spec_helper"

describe I18nLite::Backend::LocaleMeta do
  let(:locale_model) { TestLocale.new(locale: 'system', font: 'Verdana', rtl: false) }
  subject { described_class.new.merge! locale_model.attributes }

  it { is_expected.to be_a Hash }

  context 'accessors' do
    it 'is generated for elements in the hash' do
      expect(subject).to respond_to(:locale, :font, :rtl)
    end

    it 'for other methods are not generated' do
      expect {
        subject.bananas
      }.to raise_error NoMethodError
    end
  end

  context 'text direction implementation' do
    it 'provides rtl? accessor' do
      expect( subject.rtl? ).to be locale_model.rtl?
    end

    it 'ltr? shortcut is inverse of rtl' do
      expect( subject.ltr? ).to be !subject.rtl?
    end

    context 'provides HTML fiendly direction accessor' do

      it 'is RTL when rtl is set' do
        locale_model.rtl = true
        expect(subject.direction).to eq 'rtl'
      end

      it 'is LTR when rtl is not set' do
        locale_model.rtl = false
        expect(subject.direction).to eq 'ltr'
      end
    end
  end
end