# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ApiPolInvoiceList do
  subject(:invoice_list) do
    described_class.new(conn: conn, pol: pol, api_key: api_key)
  end

  let(:url) { 'https://api-na.exlibrisgroup.com' }
  let(:conn) { LspData.api_conn(url) }
  let(:api_key) { 'apikey' }
  context 'POL has invoices' do
    let(:pol) { 'POL' }
    it 'returns one invoice' do
      stub_invoice_query(query: 'pol_number~POL', fixture: 'invoice_response.json')
      expect(invoice_list.pol).to eq 'POL'
      expect(invoice_list.invoices.size).to eq 1
      expect(invoice_list.invoices.first.pid).to eq '12345'
    end
  end
  context 'POL has no invoices' do
    let(:pol) { 'POL-1' }
    it 'returns an empty array of invoices' do
      stub_invoice_query(query: 'pol_number~POL-1', fixture: 'invoice_response_no_results.json')
      expect(invoice_list.invoices).to be_empty
    end
  end
end
