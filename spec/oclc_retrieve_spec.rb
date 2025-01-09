# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
require 'byebug'

RSpec.describe LspData::OCLCRetrieve do
  subject(:retrieval) do
    described_class.new(oclc_num: oclc_num, token: token, conn: conn)
  end

  context 'OCLC record exists' do
    let(:url) { 'https://metadata.api.oclc.org/worldcat' }
    let(:conn) { api_conn(url) }
    let(:oclc_num) { '1' }
    let(:token) { 'abc' }

    it 'returns record and status code' do
      stub_oclc(fixture: 'raw_record.xml', url: url, oclc_num: oclc_num, token: token, desired_status: 200)
      expect(retrieval.status).to eq 200
      expect(retrieval.record['245']['a']).to eq 'Title'
    end
  end

  context 'OCLC record does not exist' do
    let(:url) { 'https://metadata.api.oclc.org/worldcat' }
    let(:conn) { api_conn(url) }
    let(:oclc_num) { '5' }
    let(:token) { 'abc' }

    it 'returns record and status code' do
      stub_oclc(fixture: 'raw_record.xml', url: url, oclc_num: oclc_num, token: token, desired_status: 400)
      expect(retrieval.status).to eq 400
      expect(retrieval.record).to be_nil
    end
  end
end
