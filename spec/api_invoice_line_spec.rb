# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
RSpec.describe LspData::ApiInvoiceLine do
  subject(:invoice_line) do
    described_class.new(invoice_line: stub_json_fixture(fixture: fixture))
  end
  context 'Multi-distribution retrieved via API' do
    let(:fixture) { 'invoice_line_multi_distribution.json' }
    it 'returns all invoice line basic information' do
      expect(invoice_line.pid).to eq '72345'
      expect(invoice_line.type).to eq 'Regular'
      expect(invoice_line.number).to eq '1'
      expect(invoice_line.status).to eq 'Ready'
      expect(invoice_line.price).to eq BigDecimal('1837.38')
      expect(invoice_line.quantity).to eq 1
      expect(invoice_line.note).to eq '170'
      expect(invoice_line.po_line).to eq 'POL'
      expect(invoice_line.price_note).to eq ''
      expect(invoice_line.total_price).to eq BigDecimal('1837.38')
      expect(invoice_line.vat_note).to eq 'Approximately 0.00 included in line Total Price.'
      expect(invoice_line.check_subscription_date_overlap).to be false
      expect(invoice_line.fully_invoiced).to be false
      expect(invoice_line.additional_info).to eq ''
      expect(invoice_line.release_remaining_encumbrance).to be false
      expect(invoice_line.reporting_code[:name]).to eq 'Reporting Code'
      expect(invoice_line.reporting_code[:code]).to eq '5678'
    end
    it 'returns all fund distributions' do
      expect(invoice_line.fund_distributions.size).to eq 2
      expect(invoice_line.fund_distributions[0].percent).to eq BigDecimal('80')
      expect(invoice_line.fund_distributions[1].percent).to eq BigDecimal('20')
    end
  end
end
