# frozen_string_literal: true

require 'bigdecimal'

module LspData
  ### A model of a fund transaction returned from Alma via API
  ### There is currently only a need for fund allocations,
  ###   so only fields that pertain to allocations are being parsed at this time.
  ### Types of transactions:
  ###   ALLOCATION
  ###   EXPENDITURE
  ###   ENCUMBRANCE
  ###   DISENCUMBRANCE
  ###   TRANSFER
  ### Fields to parse:
  ###   id: unique Alma identifier for fund transaction
  ###   type['value']: Transaction type
  ###   amount [make BigDecimal]
  ###   transaction_time [Time object]
  ###   transaction_reference_number: for allocations, refers to the transaction or journal ID in Prime
  ###   transaction_note: for allocations, refers to 3 pieces of information in Prime
  class AlmaFundTransaction
    attr_reader :id, :type, :amount, :transaction_time,
                :transaction_reference_number, :transaction_note

    def initialize(transaction)
      @id = transaction['id']
      @type = transaction['type']['value']
      @amount = BigDecimal(transaction['amount'])
      @transaction_time = Time.parse(transaction['transaction_time'])
      @transaction_reference_number = transaction['transaction_reference_number']
      @transaction_note = transaction['transaction_note']
    end
  end
end
