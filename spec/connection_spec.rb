# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'
RSpec.describe 'api_conn' do
  describe 'alma api connection' do
    let(:url) { 'https://api-na.exlibrisgroup.com' }
    let(:conn) { LspData.api_conn(url) }
    it 'creates an object of the class Faraday::Connection' do
      expect(conn.class).to eq Faraday::Connection
    end
  end
end

RSpec.describe 'parse_api_response' do
  let(:conn) { LspData.api_conn(url) }

  context 'response body can be parsed as JSON' do
    let(:url) { 'https://api-na.exlibrisgroup.com' }

    it 'parses the JSON API response correctly' do
      stub_invoice_query(query: 'pol_number~POL', fixture: 'invoice_response.json')
      response = conn.get do |req|
        req.url('almaws/v1/acq/invoices/?q=pol_number~POL&limit=100&offset=0&apikey=apikey')
      end
      parsed_response = LspData.parse_api_response(response)
      expect(parsed_response[:status]).to eq 200
      expect(parsed_response[:body]['total_record_count']).to eq 101
    end
  end

  context 'response body cannot be parsed as JSON' do
    let(:url) { 'https://figgy.princeton.edu' }
    it 'returns the body without parsing' do
      stub_figgy(auth_token: 'fake_token', desired_status: 403)
      response = conn.get do |req|
        req.url('reports/mms_records.json')
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.params['auth_token'] = 'fake_token'
      end
      parsed_response = LspData.parse_api_response(response)
      expect(parsed_response[:status]).to eq 403
      expect(parsed_response[:body]).to eq ''
    end
  end
end
