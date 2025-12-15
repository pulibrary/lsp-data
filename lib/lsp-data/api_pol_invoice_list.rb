# frozen_string_literal: true

module LspData
  ### Represents the list of invoices returned from an invoice API call that
  ###   finds invoices attached to a specific PO Line
  class ApiPolInvoiceList
    attr_reader :pol, :api_key, :conn

    def initialize(pol:, api_key:, conn:)
      @pol = pol
      @api_key = api_key
      @conn = conn
    end

    def invoices
      @invoices ||= all_invoices
    end

    private

    def all_invoices
      initial_response = api_call(offset: 0)
      total_invoice_count = initial_response[:body]['total_record_count']
      return [] unless total_invoice_count.size.positive?

      results = initial_response[:body]['invoice'].map { |invoice| ApiInvoice.new(invoice_json: invoice) }
      total_calls = (total_invoice_count / 100).floor
      1.upto(total_calls).each do |call|
        results += subsequent_invoice_response(call)
      end
      results
    end

    def subsequent_invoice_response(call)
      info = api_call(offset: (call * 100))
      info[:body]['invoice'].map do |invoice|
        ApiInvoice.new(invoice_json: invoice)
      end
    end

    def api_headers
      { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    end

    def api_params(offset)
      { 'apikey' => api_key, 'limit' => 100, 'offset' => offset, 'q' => "pol_number~#{pol}" }
    end

    def api_call(offset:)
      response = conn.get do |req|
        req.url 'almaws/v1/acq/invoices/'
        req.headers = api_headers
        req.params = api_params(offset)
      end
      parse_api_response(response)
    end
  end
end
