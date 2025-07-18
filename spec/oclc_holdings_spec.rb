# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::OCLCHoldings do
  subject(:retrieval) do
    described_class.new(identifier: identifier, token: token, conn: conn, target_symbols: target_symbols)
  end

  let(:url) { SEARCH_API_ENDPOINT }
  let(:conn) { api_conn(url) }

  context 'no target symbols provided for valid OCLC number with over 50 holdings' do
    let(:identifier) { { type: 'oclcNumber', value: '1' } }
    let(:token) { 'abc' }
    let(:target_symbols) { nil }
    it 'returns holdings list, status code, and total holdings count' do
      stub_oclc_holdings(fixture: 'valid_oclc_holding.json',
                         url: url,
                         identifier: identifier,
                         token: token, desired_status: 200)
      stub_oclc_holdings(fixture: 'valid_oclc_holding_page_2.json',
                         url: url,
                         identifier: identifier,
                         token: token, offset: 50, desired_status: 200)
      expect(retrieval.holdings[:status]).to eq 200
      expect(retrieval.holdings[:holdings].size).to eq 55
      expect(retrieval.holdings[:total_holdings_count]).to eq 55
      expect(retrieval.holdings[:holdings]).to include('ABY')
    end
  end

  context 'no target symbols provided for ISBN with over 50 holdings' do
    let(:identifier) { { type: 'isbn', value: '9781234567890' } }
    let(:token) { 'abc' }
    let(:target_symbols) { nil }
    it 'returns holdings list, status code, and total holdings count' do
      stub_oclc_holdings(fixture: 'valid_oclc_holding.json',
                         url: url,
                         identifier: identifier,
                         token: token, desired_status: 200)
      stub_oclc_holdings(fixture: 'valid_oclc_holding_page_2.json',
                         url: url,
                         identifier: identifier,
                         token: token, offset: 50, desired_status: 200)
      expect(retrieval.holdings[:status]).to eq 200
      expect(retrieval.holdings[:holdings].size).to eq 55
      expect(retrieval.holdings[:total_holdings_count]).to eq 55
      expect(retrieval.holdings[:holdings]).to include('ABY')
    end
  end

  context 'target symbols provided for valid OCLC number' do
    let(:identifier) { { type: 'oclcNumber', value: '1' } }
    let(:token) { 'abc' }
    let(:target_symbols) { %w[ABW ABX ABY ABZ] }
    it 'returns holdings list and status code' do
      stub_oclc_holdings(fixture: 'valid_oclc_holding_target_symbols.json',
                         url: url,
                         identifier: identifier,
                         target_symbols: target_symbols,
                         token: token, desired_status: 200)
      expect(retrieval.holdings[:status]).to eq 200
      expect(retrieval.holdings[:holdings].size).to eq 3
      expect(retrieval.holdings[:holdings]).to eq(%w[ABX ABY ABZ])
    end
  end
end
