# frozen_string_literal: true

require 'faraday'
module LspData
  def api_conn(url)
    Faraday.new(url: url) do |faraday|
      faraday.request   :url_encoded
      faraday.response  :logger
      faraday.adapter   Faraday.default_adapter
    end
  end
  def parse_api_response(response)
    { status: response.status, body: JSON.parse(response.body) }
  end
end
