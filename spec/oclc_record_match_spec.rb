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
                        credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD }
                       )
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
      desired_record = select_records.find { |record| oclcs(record:record).first == identifier }
      expect(desired_record['001'].value).to eq 'on1147930017'
    end
  end
end
