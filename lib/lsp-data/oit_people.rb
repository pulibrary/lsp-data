# frozen_string_literal: true

module LspData
  # Retrieve people from the OIT person feed and return the raw JSON of each user
  # Use path `E` for all eligible users, `I` for ineligible users
  # Use path [begin_date]/[end_date] formatted by yyyy-mm-dd for users in a specific date range
  # If you want to combine the eligible flag with dates, start with E/I, then provide the dates
  # If no additional path is provided, all users (eligible and ineligible) will be provided
  class OitPeople
    attr_reader :token, :base_url, :conn

    ELIGIBLE = 'E'
    INELIGIBLE = 'I'
    # @param token [String] Access token
    # @param base_url [string] path for API
    def initialize(token:, base_url:)
      @token = token
      @base_url = base_url
      @conn = api_conn(base_url)
    end

    # @param eligible_flag [String] optional user status (ELIGIBLE or INELIGIBLE)
    # @param dates [Hash] optional begin date;
    #   hash keys are :begin_date and :end_date, values are strings in format yyyy-mm-dd
    #   both dates must be supplied
    def report(eligible_flag: nil, dates: nil)
      url_value = api_uri(eligible_flag: eligible_flag, dates: dates)
      response = conn.get do |req|
        req.url url_value if url_value
        req.headers = report_headers
      end
      if response.status == 200
        { status: response.status, people: JSON.parse(response.body)['records']['record'] }
      else
        { status: response.status, people: nil }
      end
    end

    private

    def report_headers
      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }
    end

    def api_uri(eligible_flag:, dates:)
      return unless eligible_flag || dates

      path = ''.dup
      path << eligible_flag if eligible_flag
      path << "/#{dates[:begin_date]}/#{dates[:end_date]}" if dates
      path.delete_prefix('/')
    end
  end
end
