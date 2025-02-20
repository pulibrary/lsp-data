# frozen_string_literal: true

module LspData
  ### This class retrieves a single record from OCLC when provided with
  ###   an OAuth token, an API connection, and an OCLC number. An instance of the class
  ###   will return the following elements:
  ###     1. API Status Code
  ###     2. API Response Body
  class OCLCUnset
    attr_reader :oclc_num, :token, :conn, :status, :message

    def initialize(oclc_num:, token:, conn:)
      @oclc_num = oclc_num
      @token = token
      @conn = conn
      action = unset_holding
      @status = action.status
      @message = JSON.parse(action.body)
    end

    private

    def unset_holding
      conn.post do |req|
        req.url "manage/institution/holdings/#{oclc_num}/unset"
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.headers['Authorization'] = "Bearer #{token}"
      end
    end
  end
end
