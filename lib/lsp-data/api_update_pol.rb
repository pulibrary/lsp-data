# frozen_string_literal: true

module LspData
  ### Updates an existing portfolio for a given MMS ID and portfolio ID
  ###   with the body in JSON format; portfolio is provided as a hash
  class ApiUpdatePol
    attr_reader :mms_id, :portfolio_id, :api_key, :conn, :portfolio, :response

    def initialize(mms_id:, portfolio_id:, api_key:, conn:, portfolio:)
      @mms_id = mms_id
      @portfolio_id = portfolio_id
      @api_key = api_key
      @conn = conn
      @portfolio = portfolio
      @response ||= put_portfolio
    end

    private

    def put_portfolio
      response = api_call
      parse_api_response(response)
    end
  end

  def api_call
    conn.put do |req|
      req.url "almaws/v1/bibs/#{mms_id}/portfolios/#{portfolio_id}"
      req.headers['Content-Type'] = 'application/json'
      req.headers['Accept'] = 'application/json'
      req.params['apikey'] = api_key
      req.body = portfolio.to_json
    end
  end
end
