require "spec_helper"

describe I18nLite::Backend::LocaleMeta do
  let(:locale_model) { TestLocale.new(locale: 'system', font: 'Verdana', rtl: false) }
  subject { described_class.new( locale_model.attributes ) }

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
        expect(
          described_class.new( locale_model.attributes ).direction
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
    context 'instantiated with no data' do
      subject { described_class.new }

      it 'contains all known meta properties if instantiated with no data' do
        expect( described_class.new.to_hash ).to eq({
          'direction' => 'LTR',
          'ltr'  => true,
          'rtl'  => false,
          'font' => nil,
          'name' => nil
        })
      end
    end

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

    it 'contains name property' do
      expect( subject.to_hash ).to include(
        'name' => locale_model.name,
      )
    end
  end
end
