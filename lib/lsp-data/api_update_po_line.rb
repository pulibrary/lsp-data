# frozen_string_literal: true

module LspData
  ### Updates a PO Line from Alma in JSON format;
  ### Generally, inventory and fund distributions should be left alone,
  ###   but there are use cases for updating both of those sections
  class ApiUpdatePoLine
    attr_reader :pol_id, :pol, :api_key, :update_inventory, :redistribute_funds,
                :conn, :response

    def initialize(pol_id:, pol:, update_inventory: false,
                   redistribute_funds: false, api_key:, conn:)
      @pol_id = pol_id
      @pol = pol
      @api_key = api_key
      @conn = conn
      @redistribute_funds = redistribute_funds
      @update_inventory = update_inventory
      @response ||= update_po_line
    end

    private

    def update_po_line
      response = conn.put do |req|
        req.url "almaws/v1/acq/po-lines/#{pol_id}"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.params['apikey'] = api_key
        req.params['redistribute_funds'] = redistribute_funds
        req.params['update_inventory'] = update_inventory
        req.body = pol.to_json
      end
      parse_api_response(response)
    end
  end
end
