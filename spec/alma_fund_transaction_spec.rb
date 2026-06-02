# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'
RSpec.describe LspData::AlmaFundTransaction do
  subject(:fund_transaction) do
    described_class.new(stub_json_fixture(fixture: fixture))
  end
  context 'fund allocation retrieved via API' do
    let(:fixture) { 'fund_allocation.json' }
    it 'returns all information' do
      expect(fund_transaction.id).to eq '47106421'
      expect(fund_transaction.type).to eq 'ALLOCATION'
      expect(fund_transaction.amount).to eq BigDecimal(47_848.7)
      expect(fund_transaction.transaction_time).to eq Time.parse('2026-05-18Z')
      expect(fund_transaction.transaction_reference_number).to eq 'ABC1234567'
      expect(fund_transaction.transaction_note).to eq 'Entry | Description | 05/14/2026'
    end
  end
end
