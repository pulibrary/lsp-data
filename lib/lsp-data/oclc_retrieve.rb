# frozen_string_literal: true

module LspData
  ### This class retrieves a single record from OCLC when provided with
  ###   an OAuth token, an API connection, and an OCLC number. An instance of the class
  ###   will return the following elements:
  ###     1. Record if successful
  ###     2. API Status Code
  class OCLCRetrieve
    attr_reader :oclc_num, :token, :conn, :status, :record

    def initialize(oclc_num:, token:, conn:)
      @oclc_num = oclc_num
      @token = token
      @conn = conn
      response = api_response
      @status = response[:status]
      @record = response[:record]
    end

    private

    def api_response
      info = retrieve_record
      record = parse_record(info)
      status = info.status
      { status: status, record: record }
    end

    def parse_record(api_response)
      return unless api_response.status == 200

      temp_reader = MARC::XMLReader.new(StringIO.new(api_response.body, 'r'), parser: 'magic')
      temp_reader.first
    end

    def retrieve_record
      conn.get do |req|
        req.url "manage/bibs/#{oclc_num}"
        req.headers['accept'] = 'application/marcxml+xml'
        req.headers['content-type'] = 'application/json'
        req.headers['Authorization'] = "Bearer #{token}"
      end
    end
  end
end
