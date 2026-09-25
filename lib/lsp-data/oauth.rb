# frozen_string_literal: true

require 'base64'

module LspData
  ### This class encapsulates OAuth authentication. An instance of the class
  ###   will return the following elements:
  ###     1. Authentication token (return nil if unable to authenticate)
  ###     2. API Status Code
  ###     3. Expiration of token (return nil if unable to authenticate)
  ### OCLC provides an absolute expiration date/time of the token, while OIT
  ###   only provides a relative expiration date/time
  class OAuth
    attr_reader :client_id, :client_secret, :url, :scope, :response

    def initialize(client_id:, client_secret:, url:, scope: nil)
      @client_id = client_id
      @client_secret = client_secret
      @url = url
      @scope = scope
      @response = parse_request
    end

    private

    def authorization
      Base64.strict_encode64("#{client_id}:#{client_secret}")
    end

    def auth_request_headers
      { 'Accept' => 'application/json',
        'Authorization' => "Basic #{authorization}" }
    end

    def auth_request_params
      params = { 'grant_type' => 'client_credentials' }
      params.merge!({ 'scope' => scope }) if scope
      params
    end

    def auth_request_api
      conn = api_conn(url)
      conn.post do |req|
        req.headers = auth_request_headers
        req.params = auth_request_params
      end
    end

    def parse_request
      request = auth_request_api
      token = nil
      expiration = nil
      status = request.status
      if status == 200
        doc = JSON.parse(request.body)
        expiration = parse_expiration(doc)
        token = doc['access_token']
      end
      { status: status, expiration: expiration, token: token }
    end

    def parse_expiration(doc)
      if doc['expires_at']
        parse_absolute_expiration(doc['expires_at'])
      else
        parse_relative_expiration(doc['expires_in'])
      end
    end

    ### Time returned is GMT for absolute expiration; have to convert to the local time zone
    def parse_absolute_expiration(expires_at)
      regex = /^([0-9]{4})-([0-9]{2})-([0-9]{2})\s+([0-9]{2}):([0-9]{2}):([0-9]{2})Z.*$/
      time_parts = regex.match(expires_at)
      year = time_parts[1].to_i
      month = time_parts[2].to_i
      day = time_parts[3].to_i
      hour = time_parts[4].to_i
      minute = time_parts[5].to_i
      second = time_parts[6].to_i
      Time.utc(year, month, day, hour, minute, second).localtime
    end

    def parse_relative_expiration(expires_in)
      Time.now + expires_in.to_i
    end
  end
end
