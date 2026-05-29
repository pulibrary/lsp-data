# frozen_string_literal: true

module LspData
  ### Retrieves fund transactions for a given fund ID and parses them
  ###   as AlmaFundTransaction objects.
  ### Currently, only a pathway for retrieving allocations is needed.
  class ApiRetrieveFundTransactions
    attr_reader :api_key, :conn, :fund_id

    def initialize(api_key:, conn:, fund_id:)
      @api_key = api_key
      @conn = conn
      @fund_id = fund_id
    end

    def allocations
      @allocations ||= retrieve_transactions(type: 'ALLOCATED')
    end

    private

    def retrieve_transactions(type:)
      initial_response = api_call(offset: 0, type: type)
      total_transaction_count = initial_response[:body]['total_record_count']
      return [] unless total_transaction_count.size.positive?

      results = initial_response[:body]['fund_transaction'].map { |transaction| AlmaFundTransaction.new(transaction) }
      total_calls = (total_transaction_count / 100).floor
      1.upto(total_calls).each do |call|
        results += subsequent_api_response(call: call, type: type)
      end
      results
    end

    def subsequent_api_response(call:, type:)
      info = api_call(offset: (call * 100), type: type)
      info[:body]['fund_transaction'].map { |transaction| AlmaFundTransaction.new(transaction) }
    end

    def api_headers
      { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    end

    def api_params(offset:, type:)
      {
        'apikey' => api_key,
        'limit' => 100,
        'offset' => offset,
        'filter' => type
      }
    end

    def api_call(offset:, type:)
      response = conn.get do |req|
        req.url "almaws/v1/acq/funds/#{fund_id}/transactions"
        req.headers = api_headers
        req.params = api_params(offset:, type:)
      end
      parse_api_response(response)
    end
  end
end
