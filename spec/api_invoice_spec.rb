# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
RSpec.describe LspData::ApiInvoice do
  subject(:invoice) do
    described_class.new(invoice_json: stub_individual_invoice(fixture: fixture))
  end
  context 'invoice retrieved via API' do
    let(:fixture) { 'individual_invoice.json' }
    it 'returns expected invoice header information' do
      expect(invoice.pid).to eq '11223897611702345'
      expect(invoice.invoice_number).to eq '23456'
      expect(invoice.vendor[:code]).to eq 'VENDOR'
      expect(invoice.vendor[:name]).to eq 'Vendor'
      expect(invoice.vendor[:account]).to eq 'Account'
      expect(invoice.currency[:code]).to eq 'USD'
      expect(invoice.currency[:name]).to eq 'US Dollar'
      expect(invoice.owner).to eq 'techserv'
      expect(invoice.invoice_date).to eq Time.new(2022, 1, 28)
      expect(invoice.invoice_total).to eq BigDecimal('1837.38')
      expect(invoice.invoice_lines_total).to eq BigDecimal('1837.38')
      expect(invoice.reference_number).to be_nil
      expect(invoice.creation_method).to eq 'Manually'
      expect(invoice.status).to eq 'Closed'
      expect(invoice.workflow_status).to be nil
      expect(invoice.approval_status).to eq 'Approved'
      expect(invoice.approver).to eq 'Staff User'
      expect(invoice.approval_date).to eq Time.new(2022, 5, 27)
      expect(invoice.use_pro_rata).to be false
      expect(invoice.alerts).to include 'Currency different from PO'
      expect(invoice.invoice_notes).to be_empty
    end

    it 'returns expected invoice payment information' do
      expect(invoice.payment[:prepaid]).to be false
      expect(invoice.payment[:internal_copy]).to be false
      expect(invoice.payment[:payment_status]).to eq 'Paid'
      expect(invoice.payment[:payment_method]).to eq 'Payment Method'
      expect(invoice.voucher_date).to eq Time.new(2022, 6, 1)
      expect(invoice.voucher_number).to eq 'A1111111'
      expect(invoice.calculated_voucher_number).to eq 'A1111111'
      expect(invoice.voucher_amount).to eq BigDecimal('1837.38')
      expect(invoice.voucher_currency[:name]).to eq 'US Dollar'
      expect(invoice.voucher_currency[:code]).to eq 'USD'
      expect(invoice.additional_charges['shipment']).to eq BigDecimal('0')
    end
  end

  context 'invoice retrieved via API with info missing from first invoice' do
    let(:fixture) { 'individual_invoice_2.json' }
    it 'returns expected invoice header information' do
      expect(invoice.pid).to eq '11223847611702345'
      expect(invoice.reference_number).to eq '14234-1'
      expect(invoice.invoice_notes.first[:content]).to eq 'Invoice Includes Service Charge'
      expect(invoice.invoice_notes.first[:creation_date]).to eq '2024-12-11'
      expect(invoice.invoice_notes.first[:creator]).to eq 'System'
    end
  end
end
