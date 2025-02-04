# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::PolReceive do
  subject(:receipt) do
    described_class.new(conn: conn,
                        pol: pol,
                        item_id: item_id,
                        dept_library: dept_library,
                        dept: dept,
                        api_key: api_key)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  let(:dept_library) { 'lib' }
  let(:dept) { 'dept' }
  context 'Item is able to be received' do
    let(:pol) { 'POL' }
    let(:item_id) { '2316435' }
    let(:status) { 200 }
    it 'returns item information' do
      stub_receive_response(pol: pol, item_id: item_id, fixture: 'receive_success.json', status: status)
      expect(receipt.response[:info][:barcode]).to eq 'test4567'
    end
  end
  context 'Item is unable to be received' do
    let(:pol) { 'POL' }
    let(:item_id) { '2316435' }
    let(:status) { 400 }
    it 'returns receiving errors' do
      stub_receive_response(pol: pol, item_id: item_id, fixture: 'receive_errors.json', status: status)
      expect(receipt.response[:info][:errors].first).to eq 'Failed to receive the PO Line item. Errors: Item already received ; '
    end
  end
end
