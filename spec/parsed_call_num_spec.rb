# frozen_string_literal: true

require_relative './../lib/lsp-data'

RSpec.describe LspData::ParsedCallNumber do
  subject(:call_num) do
    described_class.new(primary_subfield: primary_subfield, item_subfields: item_subfields, assume_lc: assume_lc)
  end

  context 'non-LC field has multiple Cutters' do
    let(:assume_lc) { false }
    let(:primary_subfield) { MARC::Subfield.new('a', 'PS3556.S32') }
    let(:item_subfields) { [
                             MARC::Subfield.new('b', '.F2'),
                             MARC::Subfield.new('b', '.G312')
                           ] }

    it 'does not parse call number as an LC call number' do
      expect(call_num.primary_lc_class).to be_nil
      expect(call_num.sub_lc_class).to be_nil
      expect(call_num.classification).to eq primary_subfield.value
      expect(call_num.cutters).to eq ['.F2', '.G312']
      expect(call_num.lc?).to be false
    end
  end

  context 'LC primary field does not start with a letter' do
    let(:assume_lc) { true }
    let(:primary_subfield) { MARC::Subfield.new('a', '1PS3556.S32') }
    let(:item_subfields) { [
                             MARC::Subfield.new('b', '.F2'),
                             MARC::Subfield.new('b', '.G312')
                           ] }

    it 'does not parse call number as an LC call number' do
      expect(call_num.primary_lc_class).to be_nil
      expect(call_num.sub_lc_class).to be_nil
      expect(call_num.classification).to eq primary_subfield.value
      expect(call_num.cutters).to eq ['.F2', '.G312']
      expect(call_num.lc?).to be false
    end
  end

  context 'LC call number field is well-formed' do
    let(:assume_lc) { true }
    let(:primary_subfield) { MARC::Subfield.new('a', 'PS3556.S32') }
    let(:item_subfields) { [
                             MARC::Subfield.new('b', '.F2')
                           ] }

    it 'parses the LC call number correctly' do
      expect(call_num.primary_lc_class).to eq 'P'
      expect(call_num.sub_lc_class).to eq 'PS'
      expect(call_num.classification).to eq primary_subfield.value
      expect(call_num.cutters).to eq ['.F2']
      expect(call_num.lc?).to be true
    end
  end
end
