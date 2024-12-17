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
  context 'POL has invoices spread across two pages' do
    let(:pol) { 'POL' }
    it 'returns both invoices' do
      stub_invoice_query(query: 'pol_number~POL', fixture: 'invoice_response.json')
      stub_invoice_query(query: 'pol_number~POL', fixture: 'invoice_response_page_2.json', offset: 100)
      expect(invoice_list.invoices.size).to eq 2
      expect(invoice_list.invoices[0].pid).to eq '12345'
      expect(invoice_list.invoices[1].pid).to eq '112345'
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
