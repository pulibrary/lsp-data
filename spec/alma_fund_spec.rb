# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::AlmaFund do
  subject(:alma_fund) do
    described_class.new(stub_json_fixture(fixture: fixture))
  end

  context 'fund is passed from an API call' do
    let(:fixture) { 'alma_fund.json' }
    let(:expected_balances) do
      {
        allocated_balance: BigDecimal('4707060.95'),
        expended_balance: BigDecimal('3217413.43'),
        cash_balance: BigDecimal('1489647.52'),
        encumbered_balance: BigDecimal('228875.27'),
        available_balance: BigDecimal('1260772.25')
      }
    end

    it 'has all required elements' do
      expect(alma_fund.id).to eq '43106421'
      expect(alma_fund.code).to eq 'fund1'
      expect(alma_fund.name).to eq 'Acquisitions Fund 1'
      expect(alma_fund.description).to eq 'A0101'
      expect(alma_fund.chartstring).to eq '12345|E1234'
      expect(alma_fund.type).to eq 'ALLOCATED'
      expect(alma_fund.balances).to eq expected_balances
      expect(alma_fund.notes).to eq [{ note: 'Note 1', creation_date: Time.parse('2025-10-03Z'), creator: '123456789' }]
    end
  end
end
