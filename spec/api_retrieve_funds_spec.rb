# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiRetrieveFunds do
  subject(:funds) do
    described_class.new(conn: conn, api_key: api_key)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'allocated funds are spread across 2 pages' do
    it 'returns both funds' do
      stub_fund_query(fixture: 'fund_response.json', type: 'ALLOCATED')
      stub_fund_query(fixture: 'fund_response_page_2.json', type: 'ALLOCATED', offset: 100)
      expect(funds.allocated_funds.size).to eq 2
      expect(funds.allocated_funds[0].id).to eq '43106421'
      expect(funds.allocated_funds[1].id).to eq '43306421'
    end
  end
end
