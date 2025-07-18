# frozen_string_literal: true

module LspData
  ### This class retrieves holdings from the OCLC Search API for a given identifier
  ### when provided with an OAuth token, an API connection, and an identifier.
  ### You can optionally provide specific OCLC symbols.
  ### The Search API will only return up to 500 holdings.
  ### If an ISBN or ISSN is given, only the first record is returned from the API.
  ### An instance of the class will return the following elements:
  ###   1. OCLC Symbols of holding libraries [up to 10 returned]
  ###   2. API Status Code
  ### Types of identifiers accepted:
  ###   1. oclcNumber
  ###   2. isbn [10 digit or 13 digit]
  ###   3. issn [xxxx-xxxx]
  class OCLCHoldings
    attr_reader :identifier, :token, :conn, :target_symbols

    def initialize(identifier:, token:, conn:, target_symbols: nil)
      @identifier = identifier
      @token = token
      @conn = conn
      @target_symbols = target_symbols
    end

    def holdings
      initial_response = api_call
      holdings = holdings_from_response(initial_response[:body])
      return { status: initial_response[:status], holdings: holdings } if holdings.empty?

      total_holdings_count = initial_response[:body]['briefRecords'].first['institutionHolding']['totalHoldingCount']
      holdings += subsequent_holdings(total_holdings_count: total_holdings_count)
      { status: initial_response[:status], holdings: holdings, total_holdings_count: total_holdings_count }
    end

    private

    def subsequent_holdings(total_holdings_count:)
      all = []
      total_calls = (total_holdings_count / 50).floor
      1.upto(total_calls).each do |number|
        api_response = api_call(offset: (number * 50))
        break if api_response[:status] != 200

        all += holdings_from_response(api_response[:body])
      end
      all
    end

    def holdings_from_response(response)
      records = response['briefRecords'].first
      return [] unless records && records['institutionHolding']['totalHoldingCount'] != 0

      records['institutionHolding']['briefHoldings'].map { |holding| holding['oclcSymbol'] }
                                                    .reject(&:nil?)
    end

    def api_params(offset:)
      hash = { identifier[:type] => identifier[:value], 'limit' => 50 }
      hash['offset'] = offset if offset
      hash['heldBySymbol'] = target_symbols.join(',') if target_symbols
      hash
    end

    def api_call(offset: nil)
      response = conn.get do |req|
        req.url 'bibs-holdings'
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.headers['Authorization'] = "Bearer #{token}"
        req.params = api_params(offset: offset)
      end
      parse_api_response(response)
    end
  end
end
