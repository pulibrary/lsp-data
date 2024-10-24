require 'faraday'
module LspData
  def api_conn(url)
    Faraday.new(url: url) do |faraday|
      faraday.request   :url_encoded
      faraday.response  :logger
      faraday.adapter   Faraday.default_adapter
    end
  end
end
