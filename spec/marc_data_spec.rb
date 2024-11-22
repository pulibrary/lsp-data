# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'byebug'
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
      call_nums = LspData.call_num_from_bib_field(record: record,
                                                  field_tag: '050')
      expect(call_nums.map(&:full_call_num)).to eq target_array
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
      call_nums = LspData.call_num_from_bib_field(record: record,
                                       field_tag: '090')
      expect(call_nums.map(&:full_call_num)).to eq target_array
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
        { '852' => { 'ind1' => '8',
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
      holding_id = '2216124'
      target_array = ['M269 .C69']
      call_nums = LspData.call_num_from_alma_holding_field(record: record,
                                                      field_tag: field_tag,
                                                      inst_suffix: inst_suffix,
                                                      lc_only: false)
      expect(call_nums[holding_id].map(&:full_call_num)).to eq target_array
    end
  end

  context 'record has no 852 fields' do
    let(:fields) do
      [
        { '050' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [{ 'a' => 'M269' }, { 'b' => '.C69 ' }] } }
      ]
    end
    it 'returns no call numbers' do
      expect(LspData.call_num_from_alma_holding_field(record: record,
                                                      field_tag: field_tag,
                                                      inst_suffix: inst_suffix)).to be_empty
    end
  end
end

RSpec.describe 'all_call_nums_from_merged_bib' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:inst_suffix) { '6124' }
  let(:holding_field_tag) { '952' }
  let(:fields) do
    [
      { '050' => { 'ind1' => ' ',
                   'ind2' => '0',
                   'subfields' => [{ 'a' => 'M269' }, { 'b' => '.C69 ' }] } },
      { '952' => { 'ind1' => '8',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'h' => 'M269' },
                     { 'i' => '.C69 ' },
                     { '8' => '2216124' }
                   ] } },
      { '952' => { 'ind1' => '0',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'h' => 'M3.1' },
                     { 'i' => '.C69 ' },
                     { '8' => '2216124' }
                   ] } },
      { '090' => { 'ind1' => ' ',
                   'ind2' => '4',
                   'subfields' => [{ 'a' => 'M3.1' }, { 'b' => '.C69 2012' }] } }
    ]
  end

  it 'returns correct call numbers' do
    target_f050 = ['M269 .C69']
    target_f090 = ['M3.1 .C69 2012']
    holding_id = '2216124'
    target_holding_call_nums = ['M3.1 .C69']
    call_nums = LspData.all_call_nums_from_merged_bib(record: record,
                                                 inst_suffix: inst_suffix,
                                                 lc_only: true,
                                                 holding_field_tag: holding_field_tag)
    expect(call_nums[:f050].map(&:full_call_num)).to eq target_f050
    expect(call_nums[:f090].map(&:full_call_num)).to eq target_f090
    expect(call_nums[:holdings][holding_id].map(&:full_call_num)).to eq target_holding_call_nums
  end
end
