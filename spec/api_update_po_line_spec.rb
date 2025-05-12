# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiUpdatePoLine do
  subject(:retrieval) do
    described_class.new(pol: pol,
                        api_key: api_key,
                        conn: conn)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'PO Line exists' do
    let(:pol_id) { 'POL-1' }
    let(:fixture) { 'po_line.json' }
    let(:pol) { stub_json_fixture(fixture: fixture) }
    let(:update_inventory) { false }
    let(:redistribute_funds) { false }
    let(:status) { 200 }
    it 'updates the PO Line and returns the POL response with the POL ID' do
      stub_put_po_line_response(pol_id: pol_id,
                                fixture: fixture,
                                update_inventory: update_inventory,
                                redistribute_funds: redistribute_funds,
                                status: status)
      expect(retrieval.response[:body]['number']).to eq pol_id
    end
  end
end
