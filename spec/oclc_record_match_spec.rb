# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::OCLCRecordMatch do
  subject(:match) do
    described_class.new(identifier: identifier, identifier_type: identifier_type, conn: conn)
  end

  let(:conn) do
    Z3950Connection.new(host: OCLC_Z3950_ENDPOINT,
                        database_name: OCLC_Z3950_DATABASE_NAME,
                        credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end

  context 'ISBN with at least one acceptable record and one unacceptable record' do
    let(:identifier) { '9781984899422' }
    let(:identifier_type) { 'isbn' }
    let(:title) { 'Disability visibility' }

    it 'returns all records regardless of acceptability' do
      all_records = match.records
      unacceptable_cat_language = all_records.any? { |record| record['040']['b'] && record['040']['b'] != 'eng' }
      expect(unacceptable_cat_language).to eq true
    end
    it 'returns filtered records when requested' do
      select_records = match.filtered_records(title)
      unacceptable_cat_language = select_records.any? { |record| record['040']['b'] && record['040']['b'] != 'eng' }
      expect(unacceptable_cat_language).to eq false
    end
  end

  context 'OCLC number provided for an acceptable record' do
    let(:identifier) { '1147930017' }
    let(:identifier_type) { 'oclc' }
    let(:title) { 'Disability visibility' }

    it 'returns the acceptable record in the filtered records' do
      select_records = match.filtered_records(title)
      desired_record = select_records.find { |record| oclcs(record: record).first == identifier }
      expect(desired_record['001'].value).to eq 'on1147930017'
    end
  end

  context 'record is returned from OCLC with 007 field that indicates electronic record' do
    let(:leader) { '01104naa a2200289 i 4500' }
    let(:fields) do
      [
        { '007' => 'c' },
        { '245' => { 'indicator1' => '0',
                     'indicator2' => '0',
                     'subfields' => [{ 'a' => 'Electronic title' }] } }
      ]
    end
    let(:record) { MARC::Record.new_from_hash('fields' => fields, 'leader' => leader) }
    let(:identifier) { '9781984899422' }
    let(:identifier_type) { 'isbn' }

    it 'identifies the record as electronic' do
      expect(match.send(:electronic_reproduction?, record)).to eq true
    end
  end

  context 'OCLC number provided for a work of Belles Lettres' do
    let(:identifier) { '292012' }
    let(:identifier_type) { 'oclc' }
    let(:title) { 'The recognitions' }

    it 'returns only records with LCGFT ' do
      select_records = match.filtered_records(title)
      lcgft_records = select_records.select do |record|
        record.fields('655').any? { |field| field.indicator2 == '7' && field['2'] == 'lcgft' }
      end
      expect(lcgft_records.size).to eq select_records.size
    end
  end
end
