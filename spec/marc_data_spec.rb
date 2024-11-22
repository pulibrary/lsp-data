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
        { '050' => { 'indicator1' => ' ',
                     'indicator2' => '0',
                     'subfields' => [{ 'a' => 'M269' }, { 'b' => '.C69 ' }] } },
        { '090' => { 'indicator1' => ' ',
                     'indicator2' => '4',
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
