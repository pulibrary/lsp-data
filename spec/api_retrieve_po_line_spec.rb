# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiRetrievePoLine do
  subject(:retrieval) do
    described_class.new(pol_id: pol_id,
                        api_key: api_key,
                        conn: conn)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'PO Line exists' do
    let(:pol_id) { 'POL-1' }
    let(:fixture) { 'po_line.json' }
    it 'returns a PO Line of the same POL ID' do
      stub_get_po_line_response(pol_id: pol_id, fixture: fixture)
      expect(retrieval.response[:body]['number']).to eq pol_id
    end
  end
end
