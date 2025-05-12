# frozen_string_literal: true

module LspData
  ### Updates a PO Line from Alma in JSON format;
  ### Generally, inventory and fund distributions should be left alone,
  ###   but there are use cases for updating both of those sections
  class ApiUpdatePoLine
    attr_reader :pol_id, :pol, :api_key, :update_inventory, :redistribute_funds,
                :conn, :response

    def initialize(pol:, api_key:, conn:, update_inventory: false,
                   redistribute_funds: false)
      @pol_id ||= pol['number']
      @pol = pol
      @api_key = api_key
      @conn = conn
      @redistribute_funds = redistribute_funds
      @update_inventory = update_inventory
      @response ||= update_po_line
    end

    private

    def api_headers
      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      }
    end

    def api_params
      {
        'apikey' => api_key,
        'redistribute_funds' => redistribute_funds,
        'update_inventory' => update_inventory
      }
    end

    def update_po_line
      response = conn.put do |req|
        req.url "almaws/v1/acq/po-lines/#{pol_id}"
        req.headers = api_headers
        req.params = api_params
        req.body = pol.to_json
      end
      parse_api_response(response)
    end
  end
end
