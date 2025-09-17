# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::FiggyReport do
  subject(:figgy_report) do
    described_class.new(report: stub_json_fixture(fixture: fixture), conn: conn)
  end
  let(:conn) { LspData.api_conn('https://figgy.princeton.edu/concern') }

  context 'MMS ID has one manifest with a portion note' do
    let(:fixture) { 'private_figgy_report_collection.json' }
    let(:mms_id) { '9913506421' }

    it 'returns an array of one AlmaDigitalObject for the MMS ID' do
      expect(figgy_report.mms_hash[mms_id].first.primary_identifier).to eq '123'
      expect(figgy_report.mms_hash[mms_id].size).to eq 1
    end
  end

  context 'MMS ID has one manifest with a portion note and one without' do
    let(:fixture) { 'private_figgy_report_collection_2.json' }
    let(:mms_id) { '99206421' }

    it 'returns only the object for the null portion note' do
      expect(figgy_report.mms_hash[mms_id].first.primary_identifier).to eq '123'
      expect(figgy_report.mms_hash[mms_id].size).to eq 1
    end
  end
end
