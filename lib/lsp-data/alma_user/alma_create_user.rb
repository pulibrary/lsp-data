# frozen_string_literal: true

module LspData
  ### This class creates a user in Alma when provided
  ###   with an API key, an API connection, and an AlmaUser object.
  ### An instance of the class will return the following elements if the
  ###   update is successful:
  ###   1. API Status Code
  ###   2. Created user (JSON format)
  ### An instance of the class will return the following elements if the
  ###   update is unsuccessful:
  ###   1. API Status Code
  ###   2. Error messages returned
  class AlmaCreateUser
    attr_reader :conn, :api_key, :user, :status, :response

    def initialize(conn:, api_key:, user:)
      @conn = conn
      @api_key = api_key
      @user = user
      @response = parse_api_response(create_user)
    end

    private

    def create_user
      conn.post do |req|
        req.url 'almaws/v1/users'
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.params['apikey'] = api_key
        req.body = user.to_json
      end
    end
  end
end
