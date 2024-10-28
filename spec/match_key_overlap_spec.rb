# frozen_string_literal: true

require_relative './../lib/lsp-data'
RSpec.describe 'strip_punctuation' do
  let(:replace_char) { '' }
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
  context 'string has all replaced characters' do
    let(:string) { "Apples & p\u0022\u002aeaches %22%are g\u003bo\u005eo\u007cd in '{}p\u007ei\u00a9e" }
    it 'replaces all characters correctly' do
      expect(LspData.strip_punctuation(string: string,
                                       replace_char: replace_char)).to eq 'Applesandpeachesaregoodinpie'
    end
  end
end
RSpec.describe 'pad_with_underscores' do
  let(:string) { 'spaces' }
  let(:string_length) { 10 }
  it 'adds underscores to make the string 10 characters long' do
    expect(LspData.pad_with_underscores(string,
                                        string_length)).to eq 'spaces____'
  end
end
RSpec.describe 'trim_max_field_length' do
  let(:string) { 'a' * 32_001 }
  it 'makes string length 32,000 characters' do
    expect(LspData.trim_max_field_length(string).length).to eq 32_000
  end
end
RSpec.describe 'normalize_string_and_remove_accents' do
  let(:string) { "piet\u00e1" }
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
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
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
        { '590' => { 'ind1' => ' ',
                     'ind2' => ' ',
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
        { '533' => { 'ind1' => ' ',
                     'ind2' => ' ',
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
    let(:fields) { [{ '007' => 'C' }] }
    it 'identifies the record as electronic' do
      expect(LspData.get_format_character(record)).to eq 'e'
    end
  end
  context 'record has SuDoc and URL' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '856' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'u' => 'https://website.com' }
                     ] } },
        { '086' => { 'ind1' => '0',
                     'ind2' => ' ',
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
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
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
      { '245' => { 'ind1' => '0',
                   'ind2' => ' ',
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
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Main' },
                       { '6' => '880-01' }
                     ] } },
        { '880' => { 'ind1' => '0',
                     'ind2' => ' ',
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
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
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
        { '100' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Main' }
                     ] } }
      ]
    end
    it 'returns 70 underscores' do
      expect(LspData.get_title_key(record)).to eq ('_' * 70).to_s
    end
  end
end
RSpec.describe 'get_gmd_key' do
  let(:leader) { '01104naa a2200289 i 4500' }
  context '245$h has [test]' do
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
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
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
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
RSpec.describe 'get_pub_date_key' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:leader) { '01104nam a2200289 i 4500' }
  context 'record has valid date2 in 008' do
    let(:fields) do
      [
        { '008' => '111111t19861984' }
      ]
    end
    it 'returns date2 from 008' do
      expect(LspData.get_pub_date_key(record)).to eq '1984'
    end
  end
  context 'record has invalid date2 in 008 and no 26x' do
    let(:fields) do
      [
        { '008' => '111111t1986198u' }
      ]
    end
    it 'returns 0000' do
      expect(LspData.get_pub_date_key(record)).to eq '0000'
    end
  end
  context 'record has invalid date2 in 008 and 264s for publication and copyright' do
    let(:fields) do
      [
        { '008' => '111111t1986198u' },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '1',
                     'subfields' => [
                       { 'c' => '1981' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '4',
                     'subfields' => [
                       { 'c' => '1983' }
                     ] } }
      ]
    end
    it 'returns date from publication 264' do
      expect(LspData.get_pub_date_key(record)).to eq '1981'
    end
  end
  context 'record has no 008 and 264s for copyright and distribution' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '2',
                     'subfields' => [
                       { 'c' => '1982' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '4',
                     'subfields' => [
                       { 'c' => '1984' }
                     ] } }
      ]
    end
    it 'returns date from copyright 264' do
      expect(LspData.get_pub_date_key(record)).to eq '1984'
    end
  end
  context 'record has no 008 and 264s for distribution and manufacture' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '2',
                     'subfields' => [
                       { 'c' => '1982' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '3',
                     'subfields' => [
                       { 'c' => '1983' }
                     ] } }
      ]
    end
    it 'returns date from distribution 264' do
      expect(LspData.get_pub_date_key(record)).to eq '1982'
    end
  end
  context 'record has no 008, 260 field, and 264 for production' do
    let(:fields) do
      [
        { '260' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'c' => '1960' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [
                       { 'c' => '1980' }
                     ] } }
      ]
    end
    it 'returns date from production 264' do
      expect(LspData.get_pub_date_key(record)).to eq '1980'
    end
  end
  context 'record has no 008, 260 field, and 264 with no date' do
    let(:fields) do
      [
        { '260' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'c' => '1960' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [
                       { 'a' => 'Philadelphia' }
                     ] } }
      ]
    end
    it 'returns date from 260 field' do
      expect(LspData.get_pub_date_key(record)).to eq '1960'
    end
  end
  context 'record has no 008 or 26x field with date' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '1',
                     'subfields' => [
                       { 'a' => 'Philadelphia' }
                     ] } }
      ]
    end
    it 'returns 0000' do
      expect(LspData.get_pub_date_key(record)).to eq '0000'
    end
  end
end
RSpec.describe 'get_pagination_key' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:leader) { '01104nam a2200289 i 4500' }
  context 'record has no 300 field' do
    let(:fields) do
      [
        { '008' => '111111t19861984' }
      ]
    end
    it 'returns 4 underscores' do
      expect(LspData.get_pagination_key(record)).to eq '____'
    end
  end
  context 'record has 300 field with pagination below 1,000 pages' do
    let(:fields) do
      [
        { '300' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Has 300 pages' }
                     ] } }

      ]
    end
    it 'returns 4 underscores' do
      expect(LspData.get_pagination_key(record)).to eq '____'
    end
  end
  context 'record has 300 field with pagination above 1,000 pages' do
    let(:fields) do
      [
        { '300' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Has 4001 pages' }
                     ] } }

      ]
    end
    it 'returns pagination' do
      expect(LspData.get_pagination_key(record)).to eq '4001'
    end
  end
  context 'record has 300 field with no pagination in subfield a' do
    let(:fields) do
      [
        { '300' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Has pages' }
                     ] } }
      ]
    end
    it 'returns 4 underscores' do
      expect(LspData.get_pagination_key(record)).to eq '____'
    end
  end
end
RSpec.describe 'get_edition_key' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:leader) { '01104nam a2200289 i 4500' }
  context 'record has no 250$a' do
    let(:fields) do
      [
        { '250' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { '3' => 'First work' }
                     ] } }
      ]
    end
    it 'returns 3 underscores' do
      expect(LspData.get_edition_key(record)).to eq '___'
    end
  end
  context 'record has 250a with numbers 1-3 in word form' do
    let(:fields) do
      [
        { '250' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'random firthisec' }
                     ] } }
      ]
    end
    it 'returns numbers' do
      expect(LspData.get_edition_key(record)).to eq '132'
    end
  end
  context 'record has 250a with numbers 4-6 in word form' do
    let(:fields) do
      [
        { '250' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'foufivsixlaugh' }
                     ] } }
      ]
    end
    it 'returns numbers' do
      expect(LspData.get_edition_key(record)).to eq '456'
    end
  end
  context 'record has 250a with numbers 7-9 in word form' do
    let(:fields) do
      [
        { '250' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'seveignin' }
                     ] } }
      ]
    end
    it 'returns numbers' do
      expect(LspData.get_edition_key(record)).to eq '789'
    end
  end
  context 'record has 250a with 2-letter word' do
    let(:fields) do
      [
        { '250' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '!ok' }
                     ] } }
      ]
    end
    it 'returns 2-letter word with padding' do
      expect(LspData.get_edition_key(record)).to eq 'ok_'
    end
  end
end
RSpec.describe 'get_publisher' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:leader) { '01104nam a2200289 i 4500' }
  context 'record has no publisher info' do
    let(:fields) do
      [
        { '008' => '111111t1986198u' }
      ]
    end
    it 'returns 5 underscores' do
      expect(LspData.get_publisher_key(record)).to eq '_____'
    end
  end
  context 'record has 264s for publication and copyright' do
    let(:fields) do
      [
        { '008' => '111111t1986198u' },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '1',
                     'subfields' => [
                       { 'b' => 'publisher' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '4',
                     'subfields' => [
                       { 'b' => 'copyright' }
                     ] } }
      ]
    end
    it 'returns publisher from publication 264' do
      expect(LspData.get_publisher_key(record)).to eq 'publi'
    end
  end
  context 'record has 264s for copyright and distribution' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '2',
                     'subfields' => [
                       { 'b' => 'distribution' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '4',
                     'subfields' => [
                       { 'b' => 'copyright' }
                     ] } }
      ]
    end
    it 'returns publisher from copyright 264' do
      expect(LspData.get_publisher_key(record)).to eq 'copyr'
    end
  end
  context 'record has 264s for distribution and manufacture' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '2',
                     'subfields' => [
                       { 'b' => 'distribution' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '3',
                     'subfields' => [
                       { 'c' => 'manufacture' }
                     ] } }
      ]
    end
    it 'returns publisher from distribution 264' do
      expect(LspData.get_publisher_key(record)).to eq 'distr'
    end
  end
  context 'record has 260 field and 264 for production' do
    let(:fields) do
      [
        { '260' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'b' => 'Two sixty' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [
                       { 'b' => 'production' }
                     ] } }
      ]
    end
    it 'returns publisher from production 264' do
      expect(LspData.get_publisher_key(record)).to eq 'produ'
    end
  end
  context 'record has 260 field and 264 with no publisher' do
    let(:fields) do
      [
        { '260' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'b' => 'Two sixty' }
                     ] } },
        { '264' => { 'ind1' => ' ',
                     'ind2' => '0',
                     'subfields' => [
                       { 'a' => 'Philadelphia' }
                     ] } }
      ]
    end
    it 'returns publisher from 260 field' do
      expect(LspData.get_publisher_key(record)).to eq 'two_s'
    end
  end
  context 'record has no 26x field with publisher' do
    let(:fields) do
      [
        { '264' => { 'ind1' => ' ',
                     'ind2' => '1',
                     'subfields' => [
                       { 'a' => 'Philadelphia' }
                     ] } }
      ]
    end
    it 'returns 5 underscores' do
      expect(LspData.get_publisher_key(record)).to eq '_____'
    end
  end
end
RSpec.describe 'get_type_key' do
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:fields) do
    [
      { '245' => { 'ind1' => '0',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'a' => 'record' },
                     { 'h' => 'electronic resource' }
                   ] } }
    ]
  end
  context 'leader is less than 10 characters' do
    let(:leader) { '01104naa' }
    it 'returns one underscore' do
      expect(LspData.get_type_key(record)).to eq '_'
    end
  end
  context 'leader position 6 has a diacritic' do
    let(:leader) { "01104n\u00e1m a2200289 i 4500" }
    it 'returns the type without a diacritic' do
      expect(LspData.get_type_key(record)).to eq 'a'
    end
  end
end
RSpec.describe 'get_title_part_key' do
  let(:leader) { '01104nam a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  context 'has no 245$p' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'h' => 'electronic resource' }
                     ] } }
      ]
    end
    it 'returns 30 underscores' do
      expect(LspData.get_title_part_key(record)).to eq ('_' * 30).to_s
    end
  end
  context 'has multiple 245$p' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'p' => 'First try.' },
                       { 'p' => 'Second part' }
                     ] } }
      ]
    end
    it 'returns first 10 normalized characters of each part' do
      expect(LspData.get_title_part_key(record)).to eq "first_try_second_par#{'_' * 10}"
    end
  end
end
RSpec.describe 'get_title_number_key' do
  let(:leader) { '01104nam a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  context 'has no 245$n' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'h' => 'electronic resource' }
                     ] } }
      ]
    end
    it 'returns 10 underscores' do
      expect(LspData.get_title_number_key(record)).to eq ('_' * 10).to_s
    end
  end
  context 'has multiple 245$n' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'n' => "N\u00famero tres." }
                     ] } }
      ]
    end
    it 'returns first 10 normalized characters' do
      expect(LspData.get_title_number_key(record)).to eq 'numero_tre'
    end
  end
end
RSpec.describe 'get_author_key' do
  let(:leader) { '01104nam a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  context 'has no 1xx field' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'h' => 'electronic resource' }
                     ] } }
      ]
    end
    it 'returns 20 underscores' do
      expect(LspData.get_author_key(record)).to eq ('_' * 20).to_s
    end
  end
  context 'has multiple 1xx fields' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'n' => "N\u00famero tres." }
                     ] } },
        { '100' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => "\u00c9t\u00e9" }
                     ] } },
        { '110' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Dog B.' }
                     ] } }
      ]
    end
    it 'returns normalized string padded to 20 characters' do
      expect(LspData.get_author_key(record)).to eq "etedog_b#{'_' * 12}"
    end
  end
end
RSpec.describe 'get_title_date_key' do
  let(:leader) { '01104nam a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  context 'has no 245$f' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'h' => 'electronic resource' }
                     ] } }
      ]
    end
    it 'returns 15 underscores' do
      expect(LspData.get_title_date_key(record)).to eq ('_' * 15).to_s
    end
  end
  context 'has 245$f field' do
    let(:fields) do
      [
        { '245' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'record' },
                       { 'f' => 'The year 1905 in the month of May' }
                     ] } }
      ]
    end
    it 'returns normalized string trimmed to 15 characters' do
      expect(LspData.get_title_date_key(record)).to eq 'year_1905_in_th'
    end
  end
end
RSpec.describe 'get_gov_doc_key' do
  let(:leader) { '01104nam a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  context 'has no 086$a' do
    let(:fields) do
      [
        { '086' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'z' => 'A 1' }
                     ] } }
      ]
    end
    it 'returns an empty character' do
      expect(LspData.get_gov_doc_key(record)).to eq ''
    end
  end
  context 'has an 086$a' do
    let(:fields) do
      [
        { '086' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Y 123.1:5' }
                     ] } }
      ]
    end
    it 'returns normalized string' do
      expect(LspData.get_gov_doc_key(record)).to eq 'y 123 1 5'
    end
  end
end
RSpec.describe 'get_match_key' do
  let(:leader) { '01104nam a2200289 i 4500' }
  let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
  let(:fields) do
    [
      { '086' => { 'ind1' => '0',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'a' => 'A 1' }
                   ] } },
      { '245' => { 'ind1' => '0',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'a' => 'This is a record.' }
                   ] } },
      { '300' => { 'ind1' => ' ',
                   'ind2' => ' ',
                   'subfields' => [
                     { 'a' => '2001 pages' }
                   ] } }
    ]
  end
  let(:match_key) do
    'this_is_a_record___________________________________________________________00002001________a___________________________________________________________________________1p'
  end
  it 'returns a complete match key' do
    expect(LspData.get_match_key(record)).to eq match_key
  end
end
