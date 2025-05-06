# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiRetrievePortfolio do
  subject(:retrieval) do
    described_class.new(mms_id: mms_id,
                        portfolio_id: portfolio_id,
                        api_key: api_key,
                        conn: conn)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }

  context 'Portfolio in an electronic collection' do
    let(:mms_id) { '99101234' }
    let(:portfolio_id) { '53101234' }
    let(:fixture) { 'collection_portfolio.json' }
    it 'returns portfolio information including collection information' do
      stub_get_portfolio_response(mms_id: mms_id, portfolio_id: portfolio_id, fixture: fixture)
      expect(retrieval.response[:body]['id']).to eq portfolio_id
      expect(retrieval.response[:body]['electronic_collection']['id']['value']).to eq '61101234'
    end
  end

  context 'Portfolio is a standalone portfolio' do
    let(:mms_id) { '99101234' }
    let(:portfolio_id) { '53101234' }
    let(:fixture) { 'standalone_portfolio.json' }
    it 'returns portfolio information with no collection information' do
      stub_get_portfolio_response(mms_id: mms_id, portfolio_id: portfolio_id, fixture: fixture)
      expect(retrieval.response[:body]['id']).to eq portfolio_id
      expect(retrieval.response[:body]['electronic_collection']['id']['value']).to eq ''
      expect(retrieval.response[:body]['is_standalone']).to be true
    end
  end
end
