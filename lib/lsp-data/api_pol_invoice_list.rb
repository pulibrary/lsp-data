# frozen_string_literal: true

module LspData
  ### Returns a hash with the response code and an array of invoices;
  ###   if the response code is not 200, return an empty array
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
      results = initial_response[:body]['invoice'].map do |invoice|
        ApiInvoice.new(invoice_json: invoice)
      end
      if total_invoice_count.size.positive?
        total_calls = (total_invoice_count / 100).floor
        1.upto(total_calls).each do |call|
          info = api_call(offset: (call * 100))
          results += info[:body]['invoice'].map do |invoice|
            ApiInvoice.new(invoice_json: invoice)
          end
        end
      end
      @all_invoices = results
    end

    def api_call(offset:)
      response = conn.get do |req|
        req.url 'almaws/v1/acq/invoices/'
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.params['apikey'] = api_key
        req.params['limit'] = 100
        req.params['offset'] = offset
        req.params['q'] = "pol_number~#{pol}"
      end
      parse_api_response(response)
    end
  end
end
