# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::FiggyReport do
  subject(:figgy_report) do
    described_class.new(conn: conn, auth_token: 'fake_token')
  end

  context 'correct auth_token not provided' do
    let(:conn) { api_conn('https://figgy.princeton.edu') }
    let(:fixture) { 'empty_figgy_report.json' }

    it 'returns an empty report' do
      stub_figgy(auth_token: 'fake_token', desired_status: 403)
      expect(figgy_report.mms_hash).to be_empty
    end
  end

  context 'report has 2 MMS IDs with one object each with a portion note' do
    let(:conn) { api_conn('https://figgy.princeton.edu') }
    let(:fixture) { 'mms_records.json' }
    let(:mms_id1) { '9913506421' }
    let(:mms_id2) { '9923506421' }

    it 'returns both AlmaDigitalObjects' do
      stub_figgy(fixture: fixture, auth_token: 'fake_token', desired_status: 200)
      expect(figgy_report.mms_hash[mms_id1].first.marc_record['999']['a']).to eq '123'
      expect(figgy_report.mms_hash[mms_id2].first.marc_record['999']['a']).to eq '124'
    end
  end

  context 'MMS ID has one manifest with a portion note' do
    let(:conn) { api_conn('https://figgy.princeton.edu') }
    let(:fixture) { 'private_figgy_report_collection.json' }
    let(:mms_id) { '9913506421' }

    it 'returns an array of one AlmaDigitalObject for the MMS ID' do
      stub_figgy(fixture: fixture, auth_token: 'fake_token', desired_status: 200)
      expect(figgy_report.mms_hash[mms_id].first.marc_record['999']['a']).to eq '123'
      expect(figgy_report.mms_hash[mms_id].size).to eq 1
    end
  end

  context 'MMS ID has one manifest with a portion note and one without' do
    let(:conn) { api_conn('https://figgy.princeton.edu') }
    let(:fixture) { 'private_figgy_report_collection_2.json' }
    let(:mms_id) { '99206421' }

    it 'returns only the object for the null portion note' do
      stub_figgy(fixture: fixture, auth_token: 'fake_token', desired_status: 200)
      expect(figgy_report.mms_hash[mms_id].first.marc_record['999']['a']).to eq '123'
      expect(figgy_report.mms_hash[mms_id].size).to eq 1
    end
  end
end
