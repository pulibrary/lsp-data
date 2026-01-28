# frozen_string_literal: true

require 'faraday'

# Standardized method to make an API call and parse its response
module LspData
  def api_conn(url)
    Faraday.new(url: url) do |faraday|
      faraday.request   :url_encoded
      faraday.response  :logger
      faraday.adapter   Faraday.default_adapter
    end
  end

  def valid_json?(json)
    JSON.parse(json)
    true
  rescue JSON::ParserError
    false
  end

  def parse_api_response(response)
    body = valid_json?(response.body) ? JSON.parse(response.body) : response.body
    { status: response.status, body: body }
  end
end
