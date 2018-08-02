require 'spec_helper'

describe I18nLite::ActiveRecord::BulkInsert do
  let(:instance) do
    described_class.new(TestTranslation.table_name, TestTranslation.send(:columns_for_insert), data)
  end
  let(:data) do
    [{ key: 'my.test.key_one', translation: 'test 1', locale: :en, is_array: false },
     { key: 'my.test.key_two', translation: 'test 2', locale: :en, is_array: false }]
  end

  describe '#execute' do
    subject { instance.execute }

    it 'inserts each row' do
      expect {
        subject
      }.to change { TestTranslation.count }.from(0).to(2)
    end

    it 'sets timestamps' do
      subject
      TestTranslation.first.tap do |t|
        expect(t.created_at).not_to be_nil
        expect(t.updated_at).not_to be_nil
      end
    end

    context 'with nil values for some columns' do
      let(:data) do
        [{ key: 'my.test.key_one', translation: 'test 1', locale: :en },
         { key: 'my.test.key_two', locale: :en, is_array: true }]
      end

      it 'inserts each row' do
        expect {
          subject
        }.to change { TestTranslation.count }.from(0).to(2)
      end
    end

    context 'with values that need to be escaped' do
      let(:data) do
        [{ key: 'my.test.key_one', translation: "This text's apostrophe must be escaped", locale: :en }]
      end

      it 'stores the correct content' do
        expect {
          subject
        }.to change { TestTranslation.count }.from(0).to(1)
        expect(TestTranslation.first.translation).to eq "This text's apostrophe must be escaped"
      end
    end
  end
end
