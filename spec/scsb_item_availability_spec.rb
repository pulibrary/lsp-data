# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::SCSBItemAvailability do
  subject(:retrieval) do
    described_class.new(barcodes: barcodes,
                        api_key: api_key,
                        conn: conn)
  end

  let(:url) { 'https://scsb-server.com:1234' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'array of barcodes provided' do
    let(:barcodes) { %w[12345 67890] }
    let(:fixture) { 'scsb_barcodes.json' }
    let(:response_body) { 'scsb_availability_response.json' }
    let(:expected) do
      [
        {
          'errorMessage' => nil,
          'itemAvailabilityStatus' => 'Not Available',
          'itemBarcode' => '12345'
        },
        {
          'errorMessage' => nil,
          'itemAvailabilityStatus' => 'Available',
          'itemBarcode' => '67890'
        }
      ]
    end
    it 'returns an array of statuses' do
      stub_scsb_availability_response(fixture: fixture, url: url, api_key: api_key, response_body: response_body)
      expect(retrieval.response[:body]).to eq expected
    end
  end
end
# rubocop:enable Metrics/BlockLength
