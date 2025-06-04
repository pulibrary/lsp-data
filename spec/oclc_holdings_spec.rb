# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::OCLCHoldings do
  subject(:retrieval) do
    described_class.new(oclc_num: oclc_num, token: token, conn: conn, target_symbols: target_symbols)
  end

  let(:url) { SEARCH_API_ENDPOINT }
  let(:conn) { api_conn(url) }

  context 'no target symbols provided for valid number with over 50 holdings' do
    let(:oclc_num) { '1' }
    let(:token) { 'abc' }
    let(:target_symbols) { nil }
    it 'returns holdings list and status code' do
      stub_oclc_holdings(fixture: 'valid_oclc_holding.json', url: url, oclc_num: oclc_num, token: token, desired_status: 200)
      stub_oclc_holdings(fixture: 'valid_oclc_holding_page_2.json', url: url, oclc_num: oclc_num, token: token, offset: 50, desired_status: 200)
      expect(retrieval.holdings[:status]).to eq 200
      expect(retrieval.holdings[:holdings].size).to eq 53
      expect(retrieval.holdings[:holdings]).to include('ABY')
    end
  end
end
