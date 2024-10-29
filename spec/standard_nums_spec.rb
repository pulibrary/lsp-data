# frozen_string_literal: true

require_relative './../lib/lsp-data'
RSpec.describe 'lccns' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) do
    MARC::Record.new_from_hash('fields' => fields,
                               'leader' => leader)
  end

  context 'record has no 010$a' do
    let(:fields) do
      [
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'z' => 'invalid' }
                     ] } }
      ]
    end
    it 'returns an empty array' do
      expect(LspData.lccns(record)).to be_empty
    end
  end

  context 'record has duplicate 010' do
    let(:fields) do
      [
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '   85153773 ' }
                     ] } },
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '  2001627090' }
                     ] } },
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '   85153773 ' }
                     ] } }
      ]
    end
    it 'returns normalized unique lccns' do
      expect(LspData.lccns(record)).to eq %w[85153773 2001627090]
    end
  end
end
RSpec.describe 'isbns' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) do
    MARC::Record.new_from_hash('fields' => fields,
                               'leader' => leader)
  end

  context 'record has no 020$a' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'z' => 'invalid' }
                     ] } }
      ]
    end
    it 'returns an empty array' do
      expect(LspData.isbns(record)).to be_empty
    end
  end
  context 'record has 10-digit isbn that duplicates 13-digit isbn' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '1-58435-001-6' }
                     ] } },
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(pbk.) 9781584350019' }
                     ] } }
      ]
    end
    it 'returns normalized unique isbns' do
      expect(LspData.isbns(record)).to eq %w[9781584350019]
    end
  end
  context 'record has invalid isbn' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(pbk.) 9781584350018' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.isbns(record)).to be_empty
    end
  end
  context 'isbn has backslashes and introductory text' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'pbk.\\9781584350019' }
                     ] } }
      ]
    end
    it 'returns normalized isbn' do
      expect(LspData.isbns(record)).to eq %w[9781584350019]
    end
  end
  context '020 has improperly formed subfields' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '9781584350019$c(pbk.)' }
                     ] } },
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '9781584350019$q20.99' }
                     ] } }
      ]
    end
    it 'returns normalized unique isbns' do
      expect(LspData.isbns(record)).to eq %w[9781584350019]
    end
  end
  context '10-digit isbn is followed by a non-isbn character and numbers' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '1584350016a978' }
                     ] } }
      ]
    end
    it 'returns normalized isbn' do
      expect(LspData.isbns(record)).to eq %w[9781584350019]
    end
  end
  context '10-digit isbn is stored as 8 digits' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '39006772' }
                     ] } }
      ]
    end
    it 'returns normalized isbn' do
      expect(LspData.isbns(record)).to eq %w[9783900677206]
    end
  end
  context '020$a is 15 digits' do
    let(:fields) do
      [
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '390067725221234' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.isbns(record)).to be_empty
    end
  end
end
RSpec.describe 'issns' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) do
    MARC::Record.new_from_hash('fields' => fields,
                               'leader' => leader)
  end

  context 'record has no 022$a or 023$a' do
    let(:fields) do
      [
        { '022' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'z' => 'invalid' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.issns(record)).to be_empty
    end
  end
  context 'record has no dash in issn' do
    let(:fields) do
      [
        { '022' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'Print03686396' }
                     ] } }
      ]
    end
    it 'returns normalized issn' do
      expect(LspData.issns(record)).to eq %w[0368-6396]
    end
  end
  context 'record has a dash in issn in the wrong place' do
    let(:fields) do
      [
        { '022' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '036-86396 extra' }
                     ] } }
      ]
    end
    it 'returns normalized issn' do
      expect(LspData.issns(record)).to eq %w[0368-6396]
    end
  end
  context 'record has spaces in issn instead of dash' do
    let(:fields) do
      [
        { '023' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '0368   6396' }
                     ] } }
      ]
    end
    it 'returns normalized issn' do
      expect(LspData.issns(record)).to eq %w[0368-6396]
    end
  end
  context 'record has invalid issn' do
    let(:fields) do
      [
        { '023' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '0368-6397' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.issns(record)).to be_empty
    end
  end
  context 'record has letter in issn instead of dash' do
    let(:fields) do
      [
        { '023' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '036a-6396' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.issns(record)).to be_empty
    end
  end
  context 'record has an issn without the check digit' do
    let(:fields) do
      [
        { '022' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '0368-639' }
                     ] } }
      ]
    end
    it 'returns normalized issn' do
      expect(LspData.issns(record)).to eq %w[0368-6396]
    end
  end
end
RSpec.describe 'oclcs' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) do
    MARC::Record.new_from_hash('fields' => fields,
                               'leader' => leader)
  end

  context 'record has no 035$a' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'z' => 'invalid' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.oclcs(record: record)).to be_empty
    end
  end
  context '035$a has non-OCLC prefix ' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(NjP)9913506421' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.oclcs(record: record)).to be_empty
    end
  end
  context '035$a has no prefix and :input_prefix is set to false' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '9913506421' }
                     ] } }
      ]
    end
    it 'returns normalized oclc number' do
      expect(LspData.oclcs(record: record, input_prefix: false)).to eq %w[9913506421]
    end
  end
  context '035$a has no prefix and :input_prefix is set to true' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => 'number9913506421' }
                     ] } }
      ]
    end
    it 'returns empty array' do
      expect(LspData.oclcs(record: record)).to be_empty
    end
  end
  context '035$a has OCLC prefix and :output_prefix is set to true' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(OCoLC)9913506421' }
                     ] } }
      ]
    end
    it 'returns normalized oclc number with OCLC prefix' do
      expect(LspData.oclcs(record: record,
                           output_prefix: true)).to eq %w[(OCoLC)on9913506421]
    end
  end
  context '035$a has 7-digit OCLC number and :output_prefix is set to true' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '9913504' }
                     ] } }
      ]
    end
    it 'returns normalized oclc number with OCLC prefix' do
      expect(LspData.oclcs(record: record,
                           input_prefix: false,
                           output_prefix: true)).to eq %w[(OCoLC)ocm09913504]
    end
  end
  context '035$a has 9-digit OCLC number and :output_prefix is set to true' do
    let(:fields) do
      [
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '991350412' }
                     ] } }
      ]
    end
    it 'returns normalized oclc number with OCLC prefix' do
      expect(LspData.oclcs(record: record,
                           input_prefix: false,
                           output_prefix: true)).to eq %w[(OCoLC)ocn991350412]
    end
  end
end
RSpec.describe 'standard_nums' do
  let(:leader) { '01104naa a2200289 i 4500' }
  let(:record) do
    MARC::Record.new_from_hash('fields' => fields,
                               'leader' => leader)
  end

  context 'record has standard numbers with standard settings' do
    let(:fields) do
      [
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '  2001627090' }
                     ] } },
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(pbk.) 9781584350019' }
                     ] } },
        { '023' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '0368-6396' }
                     ] } },
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(OCoLC)9913506421' }
                     ] } }
      ]
    end
    it 'returns all normalized standard numbers' do
      expected_hash = {
        lccn: %w[2001627090],
        isbn: %w[9781584350019],
        issn: %w[0368-6396],
        oclc: %w[9913506421]
      }
      expect(LspData.standard_nums(record: record)).to eq expected_hash
    end
  end
  context 'record has standard numbers with :input_prefix false' do
    let(:fields) do
      [
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '  2001627090' }
                     ] } },
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(pbk.) 9781584350019' }
                     ] } },
        { '023' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '0368-6396' }
                     ] } },
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '9913506421' }
                     ] } }
      ]
    end
    it 'returns all normalized standard numbers' do
      expected_hash = {
        lccn: %w[2001627090],
        isbn: %w[9781584350019],
        issn: %w[0368-6396],
        oclc: %w[9913506421]
      }
      expect(LspData.standard_nums(record: record,
                                   input_prefix: false)).to eq expected_hash
    end
  end
  context 'record has standard numbers with :output_prefix true' do
    let(:fields) do
      [
        { '010' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '  2001627090' }
                     ] } },
        { '020' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(pbk.) 9781584350019' }
                     ] } },
        { '023' => { 'ind1' => '0',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '0368-6396' }
                     ] } },
        { '035' => { 'ind1' => ' ',
                     'ind2' => ' ',
                     'subfields' => [
                       { 'a' => '(OCoLC)9913506421' }
                     ] } }
      ]
    end
    it 'returns all normalized standard numbers' do
      expected_hash = {
        lccn: %w[2001627090],
        isbn: %w[9781584350019],
        issn: %w[0368-6396],
        oclc: %w[(OCoLC)on9913506421]
      }
      expect(LspData.standard_nums(record: record,
                                   output_prefix: true)).to eq expected_hash
    end
  end
end
