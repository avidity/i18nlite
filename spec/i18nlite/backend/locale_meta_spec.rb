require "spec_helper"

describe I18nLite::Backend::LocaleMeta do
  let(:locale_model) { TestLocale.new(locale: 'system', font: 'Verdana', rtl: false) }
  subject { described_class.new(locale_model) }

  context 'initialization' do
    it 'accepts a AR model mixing in LocaleModel' do
      expect( subject.model ).to eq locale_model
    end
  end

  context 'text direction implementation' do
    it 'provides rtl? accessor' do
      expect( subject.rtl? ).to be locale_model.rtl?
    end

    it 'ltr? shortcut is inverse of ltr' do
      expect( subject.ltr? ).to be !subject.rtl?
    end

    context 'provides HTML fiendly direction accessor' do
      it 'is RTL when rtl is set' do
        locale_model.rtl = true
        expect(
          described_class.new(locale_model).direction
        ).to eq 'RTL'
      end

      it 'is LTR when rtl is not set' do
        locale_model.rtl = false
        expect( subject.ltr? ).to be true
        expect( subject.direction ).to eq 'LTR'
      end
    end
  end

  context 'to_hash' do
    it 'contains all direction propreties' do
      expect( subject.to_hash ).to include(
        'direction' => subject.direction,
        'rtl'       => locale_model.rtl?,
        'ltr'       => subject.ltr?,
      )
    end

    it 'contains font property' do
      expect( subject.to_hash ).to include(
        'font' => locale_model.font,
      )
    end
  end
end
