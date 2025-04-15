# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiUpdatePortfolio do
  subject(:update) do
    described_class.new(mms_id: mms_id,
                        portfolio_id: portfolio_id,
                        api_key: api_key,
                        conn: conn,
                        portfolio: portfolio)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'Portfolio in an electronic collection' do
    let(:fixture) { 'collection_portfolio.json' }
    let(:portfolio) { stub_json_fixture(fixture: fixture) }
    let(:mms_id) { '99101234' }
    let(:portfolio_id) { '53101234' }
    it 'returns portfolio information including collection information' do
      stub_put_portfolio_response(mms_id: mms_id, portfolio_id: portfolio_id, fixture: fixture, status: 200)
      expect(update.response[:body]['id']).to eq portfolio_id
      expect(update.response[:body]['electronic_collection']['id']['value']).to eq '61101234'
    end
  end
end
