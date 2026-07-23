# frozen_string_literal: true

module LspData
  ### Retrieves an array of item availability responses from SCSB given an array of barcodes
  class SCSBItemAvailability
    attr_reader :barcodes, :api_key, :conn, :response

    def initialize(barcodes:, api_key:, conn:)
      @barcodes = barcodes
      @api_key = api_key
      @conn = conn
      @response ||= api_response
    end

    private

    def api_response
      response = conn.post do |req|
        req.url 'sharedCollection/itemAvailabilityStatus'
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.headers['api_key'] = api_key
        req.body = api_body.to_json
      end
      parse_api_response(response)
    end

    def api_body
      { 'barcodes' => barcodes }
    end
  end
end
