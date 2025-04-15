# frozen_string_literal: true

module LspData
  ### Retrieves a portfolio from Alma for a given MMS ID and portfolio ID
  ###   in JSON format
  class ApiRetrievePortfolio
    attr_reader :mms_id, :portfolio_id, :api_key, :conn, :response

    def initialize(mms_id:, portfolio_id:, api_key:, conn:)
      @mms_id = mms_id
      @portfolio_id = portfolio_id
      @api_key = api_key
      @conn = conn
      @response ||= retrieve_portfolio
    end

    private

    def retrieve_portfolio
      response = conn.get do |req|
        req.url "almaws/v1/bibs/#{mms_id}/portfolios/#{portfolio_id}"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
        req.params['apikey'] = api_key
      end
      parse_api_response(response)
    end
  end
end
