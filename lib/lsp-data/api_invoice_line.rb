# frozen_string_literal: true

module LspData
  ### This class makes a model of an invoice line object
  ###   returned from Alma via API.
  class ApiInvoiceLine
    attr_reader :invoice_line

    def initialize(invoice_line:)
      @invoice_line = invoice_line
    end

    # Unique Alma invoice line identifier
    def pid
      @pid ||= invoice_line['id']
    end

    def type
      @type ||= invoice_line['type']['desc']
    end

    def number
      @number ||= invoice_line['number']
    end

    def status
      @status ||= invoice_line['status']['desc']
    end

    # The price is the price in the currency of the invoice
    def price
      @price ||= BigDecimal(invoice_line['price'].to_s)
    end

    def quantity
      @quantity ||= invoice_line['quantity']
    end

    def note
      @note ||= invoice_line['note']
    end

    def po_line
      @po_line ||= invoice_line['po_line']
    end

    def price_note
      @price_note ||= invoice_line['price_note']
    end

    # Price plus any overages and minus discounts
    def total_price
      @total_price ||= BigDecimal(invoice_line['total_price'].to_s)
    end

    def vat_note
      @vat_note ||= invoice_line['vat_note']
    end

    def check_subscription_date_overlap
      @check_subscription_date_overlap ||= invoice_line['check_subscription_date_overlap']
    end

    def fully_invoiced
      @fully_invoiced ||= invoice_line['fully_invoiced']
    end

    def additional_info
      @additional_info ||= invoice_line['additional_info']
    end

    def release_remaining_encumbrance
      @release_remaining_encumbrance ||= invoice_line['release_remaining_encumbrance']
    end

    def reporting_code
      @reporting_code ||= begin
        info = invoice_line['reporting_code']
        if info['value']
          { name: info['desc'], code: info['value'] }
        end
      end
    end

    def fund_distributions
      @fund_distributions ||= invoice_line['fund_distribution'].map do |distribution|
        ApiFundDistribution.new(fund_distribution: distribution)
      end
    end
  end
end
