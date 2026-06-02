# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiRetrieveFundTransactions do
  subject(:transactions) do
    described_class.new(conn: conn, api_key: api_key, fund_id: fund_id)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'Fund has allocations across 2 pages' do
    let(:fund_id) { '43106421' }
    let(:type) { 'ALLOCATION' }
    it 'returns all allocations' do
      stub_fund_transaction_query(fixture: 'fund_transaction_response.json', fund_id: fund_id, offset: 0, type: type)
      stub_fund_transaction_query(fixture: 'fund_transaction_response_page_2.json', fund_id: fund_id, offset: 100,
                                  type: type)
      expect(transactions.allocations.map(&:id).sort).to eq %w[47106421 47206421]
    end
  end
end
