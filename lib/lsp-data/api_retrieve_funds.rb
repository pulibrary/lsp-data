# frozen_string_literal: true

module LspData
  ### Retrieves active funds from Alma and generates AlmaFund objects for them
  class ApiRetrieveFunds
    attr_reader :api_key, :conn

    def initialize(api_key:, conn:)
      @api_key = api_key
      @conn = conn
    end

    def allocated_funds
      @allocated_funds ||= retrieve_funds(type: 'ALLOCATED')
    end

    private

    def retrieve_funds(type:)
      initial_response = api_call(offset: 0, type: type)
      total_fund_count = initial_response[:body]['total_record_count']
      return [] unless total_fund_count.size.positive?

      results = initial_response[:body]['fund'].map { |fund| AlmaFund.new(fund) }
      total_calls = (total_fund_count / 100).floor
      1.upto(total_calls).each do |call|
        results += subsequent_api_response(call: call, type: type)
      end
      results
    end

    def subsequent_api_response(call:, type:)
      info = api_call(offset: (call * 100), type: type)
      info[:body]['fund'].map { |fund| AlmaFund.new(fund) }
    end

    def api_headers
      { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    end

    def api_params(offset:, type:)
      {
        'apikey' => api_key,
        'limit' => 100,
        'offset' => offset,
        'entity_type' => type,
        'status' => 'ACTIVE'
      }
    end

    def api_call(offset:, type:)
      response = conn.get do |req|
        req.url 'almaws/v1/acq/funds/'
        req.headers = api_headers
        req.params = api_params(offset:, type:)
      end
      parse_api_response(response)
    end
  end
end
