# frozen_string_literal: true

require_relative './../lib/lsp-data'
RSpec.describe 'strip_punctuation' do
  let (:replace_char) { '' }
  context "string starts with 'A'" do
    let(:string) { 'A test' }
    it 'removes the stop word' do
      expect(LspData.strip_punctuation(string: string,
        replace_char: replace_char)).to eq 'test'
    end
  end
  context "string starts with 'An'" do
    let(:string) { 'An animal' }
    it 'removes the stop word' do
      expect(LspData.strip_punctuation(string: string,
        replace_char: replace_char)).to eq 'animal'
    end
  end
  context "string starts with 'the'" do
    let(:string) { 'the best' }
    it 'removes the stop word' do
      expect(LspData.strip_punctuation(string: string,
        replace_char: replace_char)).to eq 'best'
    end
  end
  context "string has all replaced characters" do
    let(:string) { "Apples & p\u0022\u002aeaches %22%are g\u003bo\u005eo\u007cd in '{}p\u007ei\u00a9e" }
    it 'replaces all characters correctly' do
      expect(LspData.strip_punctuation(string: string,
        replace_char: replace_char)).to eq 'Applesandpeachesaregoodinpie'
    end
  end
end
RSpec.describe 'pad_with_underscores' do
  let (:string) { 'spaces' }
  let (:string_length) { 10 }
  it 'adds underscores to make the string 10 characters long' do
    expect(LspData.pad_with_underscores(string,
      string_length)).to eq 'spaces____'
  end
end
RSpec.describe 'trim_max_field_length' do
  let (:string) { 'a' * 32_001 }
  it 'makes string length 32,000 characters' do
    expect(LspData.trim_max_field_length(string).length).to eq 32_000
  end
end
RSpec.describe 'normalize_string_and_remove_accents' do
  let (:string) { "piet\u00e1" }
  it 'normalizes to :nfd and removes acute accent' do
    expect(LspData.normalize_string_and_remove_accents(string)).to eq 'pieta'
  end
end
RSpec.describe 'get_format_character' do
  let(:leader) { '01104naa a2200289 i 4500' }

  context '245$h says electronic resource' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '245' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'record' },
                                      { 'h' => 'electronic resource' }
                                    ] } }
      ]
    end
    it 'identifies the record as electronic' do
      expect(LspData.get_format_character(record)).to eq 'e'
    end
  end
  context '590$a says electronic reproduction' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '590' => { 'indicator1' => ' ',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'This is an electronic reproduction.' }
                                    ] } }
      ]
    end
    it 'identifies the record as electronic' do
      expect(LspData.get_format_character(record)).to eq 'e'
    end
  end
  context '533$a says electronic reproduction' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '533' => { 'indicator1' => ' ',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'Electronic reproduction.' }
                                    ] } }
      ]
    end
    it 'identifies the record as electronic' do
      expect(LspData.get_format_character(record)).to eq 'e'
    end
  end
  context '007 format is computer file' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) { [ { '007' => 'C' } ] }
    it 'identifies the record as electronic' do
      expect(LspData.get_format_character(record)).to eq 'e'
    end
  end
  context 'record has SuDoc and URL' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '856' => { 'indicator1' => ' ',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'u' => 'https://website.com' }
                                    ] } },
        { '086' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'A 1' }
                                    ] } }
      ]
    end
    it 'identifies the record as electronic' do
      expect(LspData.get_format_character(record)).to eq 'e'
    end
  end
  context 'record is print resource' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '245' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'record' }
                                    ] } }
      ]
    end
    it 'identifies the record as print' do
      expect(LspData.get_format_character(record)).to eq 'p'
    end
  end
end
RSpec.describe 'process_title_field' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:fields) do
    [
      { '245' => { 'indicator1' => '0',
                   'indicator2' => ' ',
                   'subfields' => [
                                    { 'a' => 'main' },
                                    { 'b' => 'b' },
                                    { 'h' => 'h' },
                                    { 'p' => 'p' }
                                  ] } }
    ]
  end
  it 'normalizes the string and makes it 70 characters long' do
    expect(LspData.process_title_field(record['245'])).to eq "mainbp#{'_' * 64}"
  end
end
RSpec.describe 'get_title_key' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:leader) { '01104naa a2200289 i 4500' }
  context 'record has 880 field' do
    let(:fields) do
      [
        { '245' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'Main' },
                                      { '6' => '880-01' }
                                    ] } },
        { '880' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'Μαιν' },
                                      { '6' => '245-01' }
                                    ] } }
      ]
    end
    it 'returns the title key from the 880 field' do
      expect(LspData.get_title_key(record)).to eq "μαιν#{'_' * 66}"
    end
  end
  context 'record has no 880 field' do
    let(:fields) do
      [
        { '245' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'Main' }
                                    ] } }
      ]
    end
    it 'returns the title key from the 245 field' do
      expect(LspData.get_title_key(record)).to eq "main#{'_' * 66}"
    end
  end
  context 'record has no 245 field' do
    let(:fields) do
      [
        { '100' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'Main' }
                                    ] } }
      ]
    end
    it 'returns 70 underscores' do
      expect(LspData.get_title_key(record)).to eq "#{'_' * 70}"
    end
  end
end
RSpec.describe 'get_gmd_key' do
  let(:leader) { '01104naa a2200289 i 4500' }
  context '245$h has [test]' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '245' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'record' },
                                      { 'h' => '[test]' }
                                    ] } }
      ]
    end
    it 'returns "test" padded to 5 characters' do
      expect(LspData.get_gmd_key(record)).to eq 'test_'
    end
  end
  context '245$h does not exist' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '245' => { 'indicator1' => '0',
                     'indicator2' => ' ',
                     'subfields' => [
                                      { 'a' => 'record' }
                                    ] } }
      ]
    end
    it 'returns 5 underscores' do
      expect(LspData.get_gmd_key(record)).to eq '_____'
    end
  end
end
