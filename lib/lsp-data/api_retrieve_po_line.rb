# frozen_string_literal: true

module LspData
  ### Retrieves a PO Line from Alma in JSON format
  class ApiRetrievePoLine
    attr_reader :pol_id, :api_key, :conn, :response

    def initialize(pol_id:, api_key:, conn:)
      @pol_id = pol_id
      @api_key = api_key
      @conn = conn
      @response ||= retrieve_po_line
    end

    private

    def retrieve_po_line
      response = conn.get do |req|
        req.url "almaws/v1/acq/po-lines/#{pol_id}"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.params['apikey'] = api_key
      end
      parse_api_response(response)
    end
  end
end
