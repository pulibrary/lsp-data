# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ChineseConversion do
  subject(:chinese_conv) do
    described_class.new
  end

  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:chi_simp_title) { '中华人民共和国' }
  let(:chi_simp_author) { '毛泽东' }
  let(:fields) do
    [
      { '100' => { 'ind1' => ' ',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'a' => chi_simp_author }
                   ] },
        '245' => { 'ind1' => '1',
                   'ind2' => '0',
                   'subfields' => [
                     { 'b' => chi_simp_title }
                   ] } }
    ]
  end

  context 'Chinese string contains some Simplified characters' do
    it 'returns a string with the characters converted to Traditional' do
      chinese_trad_title = chinese_conv.convert_string_to_trad(chi_simp_str: chi_simp_title)
      expect(chinese_trad_title).to eq '中華人民共和國'
    end
  end

  context 'Chinese record contains fields with Simplified characters' do
    it 'returns a record with characters in all fields converted to Traditional' do
      chinese_trad_rec = chinese_conv.convert_rec_to_trad(chi_simp_rec: record)
      expect(chinese_trad_rec['100']['a']).to eq '毛澤東'
      expect(chinese_trad_rec['245']['b']).to eq '中華人民共和國'
    end
  end
end
