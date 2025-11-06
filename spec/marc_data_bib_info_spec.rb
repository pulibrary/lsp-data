# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'byebug'
RSpec.describe 'author' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }

  context 'record has author in 100 field' do
    let(:fields) do
      [
        { '100' => { 'ind1' => '1',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Shakespeare,   William,' },
                       { 'd' => '1564-1616' },
                       { 'c' => '(Spirit),' },
                       { 'e' => 'author.' },
                       { '0' => 'http://id.loc.gov/authorities/names/no2017146789' }
                     ] } }
      ]
    end
    it 'skips the correct fields and cleans up the string' do
      expect(author(record)).to eq 'Shakespeare, William, 1564-1616 (Spirit)'
    end
  end

  context 'record has author in 111 field' do
    let(:fields) do
      [
        { '111' => { 'ind1' => '2',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Paris Peace Conference' },
                       { 'd' => '(1919-1920).' },
                       { 'e' => 'Aeronautical Commission,' },
                       { 'j' => 'sponsoring body.' },
                       { '0' => 'http://id.loc.gov/authorities/names/no2023022020' }
                     ] } }
      ]
    end
    it 'skips the correct fields' do
      expect(author(record)).to eq 'Paris Peace Conference (1919-1920). Aeronautical Commission'
    end
  end
end

RSpec.describe 'title' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }

  context 'record has no 245 field' do
    let(:fields) do
      [
        { '100' => { 'ind1' => '1',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Shakespeare,   William,' },
                       { 'd' => '1564-1616' },
                       { 'c' => '(Spirit).' },
                       { '0' => 'http://id.loc.gov/authorities/names/no2017146789' }
                     ] } }
      ]
    end
    it 'returns nil' do
      expect(title(record)).to be_nil
    end
  end

  context 'record has 245 field with subfield a' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '1',
                     'ind2' => '0',
                     'subfields' => [{ 'a' => 'Standard title' }] } }
      ]
    end
    it 'returns 245$a' do
      expect(title(record)).to eq 'Standard title'
    end
  end

  context 'record has 245 field without subfield a' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => '0',
                     'subfields' => [
                       { 'k' => 'Records,' },
                       { 'f' => '1939-1973,' },
                       { 'b' => 'Dublin /' },
                       { 'c' => '[by James Haversham].' }
                     ] } }
      ]
    end
    it 'returns properly formatted title' do
      expect(title(record)).to eq 'Records, 1939-1973, Dublin'
    end
  end
end

RSpec.describe 'description' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }

  context 'record does not have 300 field' do
    let(:fields) do
      [
        { '100' => { 'ind1' => '1',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Shakespeare,   William,' },
                       { 'd' => '1564-1616' },
                       { 'c' => '(Spirit),' },
                       { 'e' => 'author.' },
                       { '0' => 'http://id.loc.gov/authorities/names/no2017146789' }
                     ] } }
      ]
    end
    it 'returns nil' do
      expect(description(record)).to be_nil
    end
  end

  context 'record has 300 field' do
    let(:fields) do
      [
        { '300' => { 'ind1' => '1',
                     'ind2' => '0',
                     'subfields' => [
                       { 'a' => '1 volume  :' },
                       { 'b' => 'illustrations' }
                     ] } }
      ]
    end
    it 'provides correctly formatted value' do
      expect(description(record)).to eq '1 volume : illustrations'
    end
  end
end

RSpec.describe 'publisher' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }

  context 'record has no publisher field' do
    let(:fields) do
      [
        { '100' => { 'ind1' => '1',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Shakespeare,   William,' },
                       { 'd' => '1564-1616' },
                       { 'c' => '(Spirit),' },
                       { 'e' => 'author.' },
                       { '0' => 'http://id.loc.gov/authorities/names/no2017146789' }
                     ] } }
      ]
    end
    it 'returns nil values' do
      target_hash = { pub_place: nil, pub_name: nil, pub_date: nil }
      expect(publisher(record)).to eq target_hash
    end
  end

  context 'record has 260 field' do
    let(:fields) do
      [
        { '260' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Dublin,' },
                       { 'c' => '1960.' }
                     ] } }
      ]
    end
    it 'parses the publisher field' do
      target_hash = { pub_place: 'Dublin', pub_name: '', pub_date: '1960' }
      expect(publisher(record)).to eq target_hash
    end
  end

  context 'record has multiple 264 fields' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '4',
                     'subfields' => [{ 'c' => '©1960' }] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '1',
                     'subfields' => [
                       { 'a' => 'Dublin,' },
                       { 'c' => '1959.' }
                     ] } }

      ]
    end
    it 'parses the correct publisher field' do
      target_hash = { pub_place: 'Dublin', pub_name: '', pub_date: '1959' }
      expect(publisher(record)).to eq target_hash
    end
  end
end
