# frozen_string_literal: true

require_relative './../lib/lsp-data'
RSpec.describe 'call_num_from_bib_field' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }

  context 'record has multiple 050 fields' do
    let(:fields) do
      [
        { '050' => { 'indicator1' => ' ',
                     'indicator2' => '0',
                     'subfields' => [{ 'a' => 'M269' }, { 'b' => '.C69 ' }] } },
        { '050' => { 'indicator1' => ' ',
                     'indicator2' => '4',
                     'subfields' => [{ 'a' => 'M3.1' }, { 'b' => '.C69 2012' }] } }
      ]
    end
    it 'returns all LC call numbers' do
      target_array = ['M269 .C69', 'M3.1 .C69 2012']
      expect(LspData.call_num_from_bib_field(record: record,
                                       field_tag: '050')).to eq target_array
    end
  end
  context 'record has 090 field and 050 field and 090 is target field' do
    let(:fields) do
      [
        { '050' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [{ 'a' => 'M269' }, { 'b' => '.C69 ' }] } },
        { '090' => { 'ind1' => ' ',
                     'ind2' => '4',
                     'subfields' => [{ 'a' => 'M3.1' }, { 'b' => '.C69 2012' }] } }
      ]
    end
    it 'returns LC call numbers from 090 field' do
      target_array = ['M3.1 .C69 2012']
      expect(LspData.call_num_from_bib_field(record: record,
                                       field_tag: '090')).to eq target_array
    end
  end
end

RSpec.describe 'call_num_from_alma_holding_field' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:inst_suffix) { '6124' }
  let(:field_tag) { '852' }

  context 'record has 852 with no holding id' do
    let(:fields) do
      [
        { '852' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [{ 'h' => 'bib 852' }, { 'i' => '.C69 ' }] } }
      ]
    end
    it 'returns no call numbers' do
      expect(LspData.call_num_from_alma_holding_field(record: record,
                                                      field_tag: field_tag,
                                                      inst_suffix: inst_suffix)).to be_empty
    end
  end

  context 'record has 852 with wrong institution suffix' do
    let(:fields) do
      [
        { '852' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'h' => 'M269' },
                       { 'i' => '.C69 ' },
                       { '8' => '2213124' }
                     ] } }
      ]
    end
    it 'returns no call numbers' do
      expect(LspData.call_num_from_alma_holding_field(record: record,
                                                      field_tag: field_tag,
                                                      inst_suffix: inst_suffix)).to be_empty
    end
  end

  context 'record has one 852 with institution suffix and one without' do
    let(:fields) do
      [
        { '852' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'h' => 'M269' },
                       { 'i' => '.C69 ' },
                       { '8' => '2216124' }
                     ] } },
        { '852' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'h' => 'M3.1' },
                       { 'i' => '.C69 ' }
                     ] } }
      ]
    end
    it 'returns correct call numbers' do
      target_array = ['M269 .C69']
      expect(LspData.call_num_from_alma_holding_field(record: record,
                                                      field_tag: field_tag,
                                                      inst_suffix: inst_suffix,
                                                      lc_only: false)).to eq target_array
    end
  end

  context 'record has no 852 fields' do
    let(:fields) do
      [
        { '050' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [{ 'a' => 'M269' }, { 'b' => '.C69 ' }] } },
      ]
    end
    it 'returns no call numbers' do
      expect(LspData.call_num_from_alma_holding_field(record: record,
                                                      field_tag: field_tag,
                                                      inst_suffix: inst_suffix)).to be_empty
    end
  end
end
