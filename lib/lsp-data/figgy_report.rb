# frozen_string_literal: true

module LspData
  ### Retrieve a JSON report of MMS IDs with associated manifests,
  ###   return an array of AlmaDigitalObjects per MMS ID;
  ### If there is only one manifest with the MMS ID, return that object as an array;
  ### If there are multiple manifests, only return objects where the portion_note is null
  class FiggyReport
    attr_reader :report, :status, :conn

    def initialize(conn:, auth_token:)
      @conn = conn
      parsed_response = get_report(auth_token)
      @report = parsed_response[:body]
      @status = parsed_response[:status]
    end

    def mms_hash
      return {} if status != 200

      parse_report
    end

    private

    def relevant_manifests(manifests)
      if manifests.size == 1
        manifests
      else
        manifests.select { |manifest| manifest['portion_note'].nil? }
      end
    end

    def get_report(auth_token)
      response = conn.get do |req|
        req.url 'reports/mms_records.json'
        req.headers['accept'] = 'application/json'
        req.headers['content-type'] = 'application/json'
        req.params['auth_token'] = auth_token
      end
      parse_api_response(response)
    end

    def parse_report
      hash = {}
      report.each do |mms_id, manifests|
        hash[mms_id] ||= []
        hash[mms_id] += relevant_manifests(manifests).map do |manifest|
          AlmaDigitalObject.new(mms_id: mms_id,
                                figgy_object: FiggyDigitalObject.new(manifest_info: manifest,
                                                                     mms_id: mms_id))
        end
      end
      hash
    end
  end
end
