# frozen_string_literal: true

module LspData
  ### This class makes a model of a PO Line object
  ###   returned from Alma via API.
  class ApiPoLine
    attr_reader :po_line_json

    def initialize(po_line_json:)
      @po_line_json = po_line_json
    end

    def number
      @number ||= po_line_json['number']
    end
  end
end
