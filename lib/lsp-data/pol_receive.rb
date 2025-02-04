# frozen_string_literal: true

module LspData
  ### This class receives an item attached to a PO Line from Alma when provided
  ###   with an API key, an API connection, a PO Line ID,
  ###   a Department Library code, a Department code, and an item ID.
  ### An instance of the class will return the following elements if the
  ###   update is successful:
  ###   1. API Status Code
  ###   2. PO Line ID
  ###   3. Item barcode
  ###   4. MMS ID attached to the item
  ###   5. Holding ID attached to the item
  ###   6. Item ID
  ###   7. Library code of item
  ###   8. Location code of item
  ### An instance of the class will return the following elements if the
  ###   update is unsuccessful:
  ###   1. API Status Code
  ###   2. Error messages returned
  class PolReceive
    attr_reader :pol, :item_id, :conn, :dept_library, :dept, :api_key,
                :status, :barcode, :mms_id, :holding_id,
                :item_library, :item_location, :response

    def initialize(conn:, pol:, item_id:, dept_library:, dept:, api_key:)
      @pol = pol
      @item_id = item_id
      @conn = conn
      @dept_library = dept_library
      @dept = dept
      @api_key = api_key
      @response = api_response
    end

    private

    def api_response
      info = receive_item
      status = info.status
      { status: status, info: parse_response_body(info) }
    end

    def receive_item
      conn.post do |req|
        req.url "almaws/v1/acq/po-lines/#{pol}/items/#{item_id}"
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.params['apikey'] = api_key
        req.params['op'] = 'receive'
        req.params['department'] = dept
        req.params['department_library'] = dept_library
        req.body = { }.to_json
      end
    end

    def parse_response_body(response)
      body = JSON.parse(response.body)
      case response.status
      when 200
        successful_response_body(body)
      else
        unsuccessful_response_body(body)
      end
    end

    def successful_response_body(body)
      {
        barcode: body['item_data']['barcode'],
        mms_id: body['bib_data']['mms_id'],
        holding_id: body['holding_data']['holding_id'],
        item_library: body['item_data']['library']['value'],
        item_location: body['item_data']['location']['value']
      }
    end

    def unsuccessful_response_body(body)
      {
        errors: body['errorList']['error'].map { |error| error['errorMessage'] }
      }
    end
  end
end
