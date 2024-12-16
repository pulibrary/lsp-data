# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
RSpec.describe LspData::ApiFundDistribution do
  subject(:fund_distribution) do
    described_class.new(fund_distribution: stub_json_fixture(fixture: fixture))
  end
  context 'fund distribution retrieved via API' do
    let(:fixture) { 'distribution.json' }
    it 'returns all information' do
      expect(fund_distribution.percent).to eq BigDecimal('80')
      expect(fund_distribution.amount).to eq BigDecimal('1469.90')
      expect(fund_distribution.fund_code[:name]).to eq 'Library Fund'
      expect(fund_distribution.fund_code[:code]).to eq 'Fund-Code'
    end
  end
end
