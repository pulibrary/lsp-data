# frozen_string_literal: true

module LspData
  ### Given a JSON report of MMS IDs with associated manifests,
  ###   return an array of AlmaDigitalObjects per MMS ID;
  ### If there is only one manifest with the MMS ID, return that object as an array;
  ### If there are multiple manifests, only return objects where the portion_note is null
  class FiggyReport
    attr_reader :conn, :report

    def initialize(report:, conn:)
      @conn = conn
      @report = report
    end

    def mms_hash
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

    def parse_report
      hash = {}
      report.each do |mms_id, manifests|
        hash[mms_id] ||= []
        hash[mms_id] += relevant_manifests(manifests).map do |manifest|
          AlmaDigitalObject.new(mms_id: mms_id,
                                figgy_object: FiggyDigitalObject.new(manifest_info: manifest,
                                                                     conn: conn, mms_id: mms_id))
        end
      end
      hash
    end
  end
end
