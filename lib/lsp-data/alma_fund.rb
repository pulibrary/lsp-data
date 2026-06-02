# frozen_string_literal: true

require 'bigdecimal'

module LspData
  ### A model of a fund returned from Alma via API
  ### Fields to parse:
  ###   id: unique Alma identifier for fund
  ###   code: Alma fund code
  ###   name: Alma fund name
  ###   description: historical Voyager fund mappings
  ###   external_id: chartstring [typically only on allocated funds]
  ###   entity_type['value']: fund type
  ###   allocated_balance [string; make BigDecimal]
  ###   expended_balance [string; make BigDecimal]
  ###   cash_balance [string; make BigDecimal]
  ###   encumbered_balance [string; make BigDecimal]
  ###   available_balance [string; make BigDecimal]
  ###   note: notes with content, creation_date, and created_by
  class AlmaFund
    attr_reader :id, :code, :name, :description, :chartstring, :type,
                :balances, :notes

    def initialize(fund)
      @id = fund['id']
      @code = fund['code']
      @name = fund['name']
      @description = fund['description']
      @chartstring = fund['external_id']
      @type = fund['entity_type']['value']
      @balances = fund_balances(fund)
      @notes = parse_notes(fund['note'])
    end

    private

    def fund_balances(fund)
      {
        allocated_balance: BigDecimal(fund['allocated_balance']),
        expended_balance: BigDecimal(fund['expended_balance']),
        cash_balance: BigDecimal(fund['cash_balance']),
        encumbered_balance: BigDecimal(fund['encumbered_balance']),
        available_balance: BigDecimal(fund['available_balance'])
      }
    end

    def parse_notes(note_data)
      note_data.map do |info|
        {
          note: info['content'],
          creation_date: Time.parse(info['creation_date']),
          creator: info['created_by']
        }
      end
    end
  end
end
