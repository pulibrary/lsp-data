# frozen_string_literal: true

module LspData
  ### This class makes a model of an invoice object returned from Alma via API.
  ###   While it is meant to be a comprehensive model, there are 2 areas that
  ###     are not of interest to PUL: VAT reporting and explicit currency
  ###     conversion ratios. Those areas will not be represented.
  class ApiInvoice
    attr_reader :invoice_json

    def initialize(invoice_json:)
      @invoice_json = invoice_json
    end

    # Unique Alma invoice identifier
    def pid
      @pid ||= invoice_json['id']
    end

    def invoice_number
      @invoice_number ||= invoice_json['number']
    end

    def vendor
      @vendor ||= {
        name: invoice_json['vendor']['desc'],
        code: invoice_json['vendor']['value'],
        account: invoice_json['vendor_account']
      }
    end

    def currency
      @currency ||= {
        name: invoice_json['currency']['desc'],
        code: invoice_json['currency']['value']
      }
    end

    def owner
      @owner ||= invoice_json['owner']['value']
    end

    def payment
      @payment ||= {
        prepaid: invoice_json['payment']['prepaid'],
        internal_copy: invoice_json['payment']['prepaid'],
        payment_status: invoice_json['payment']['payment_status']['desc'],
        payment_method: invoice_json['payment_method']['desc']
      }
    end

    def voucher_date
      @voucher_date ||= begin
        regex = /^([0-9]{4})-([0-9]{2})-([0-9]{2}).*$/
        date = regex.match(invoice_json['payment']['voucher_date'])
        Time.new(date[1].to_i, date[2].to_i, date[3].to_i) if date
      end
    end

    def voucher_number
      @voucher_number ||= invoice_json['payment']['voucher_number']
    end

    def calculated_voucher_number
      @calculated_voucher_number ||= begin
        id_number_string = pid[2..-6]
        id = id_number_string.to_i
        "A#{id.to_s(36).rjust(7, '0')}"
      end
    end

    def voucher_amount
      @voucher_amount ||= begin
        amount = invoice_json['payment']['voucher_amount']
        BigDecimal(amount.to_s) if amount.size.positive?
      end
    end

    def voucher_currency
      @voucher_currency ||= begin
        value = invoice_json['payment']['voucher_currency']['desc']
        if value
          {
            name: invoice_json['payment']['voucher_currency']['desc'],
            code: invoice_json['payment']['voucher_currency']['value']
          }
        end
      end
    end

    def invoice_date
      @invoice_date ||= begin
        regex = /^([0-9]{4})-([0-9]{2})-([0-9]{2}).*$/
        date = regex.match(invoice_json['invoice_date'])
        Time.new(date[1].to_i, date[2].to_i, date[3].to_i) if date
      end
    end

    def invoice_total
      @invoice_total ||= BigDecimal(invoice_json['total_amount'].to_s)
    end

    def invoice_lines_total
      @invoice_lines_total ||= BigDecimal(invoice_json['total_invoice_lines_amount'].to_s)
    end

    def reference_number
      @reference_number ||= begin
        number = invoice_json['reference_number']
        number if number.size.positive?
      end
    end

    def creation_method
      @creation_method ||= invoice_json['creation_form']['desc']
    end

    def status
      @status ||= invoice_json['invoice_status']['desc']
    end

    def workflow_status
      @workflow_status ||= invoice_json['invoice_workflow_status']['desc']
    end

    def approval_status
      @approval_status ||= invoice_json['invoice_approval_status']['desc']
    end

    def approver
      @approver ||= invoice_json['approved_by']
    end

    def approval_date
      @approval_date ||= begin
        regex = /^([0-9]{4})-([0-9]{2})-([0-9]{2}).*$/
        date = regex.match(invoice_json['approval_date'])
        Time.new(date[1].to_i, date[2].to_i, date[3].to_i) if date
      end
    end

    def additional_charges
      @additional_charges ||= begin
        charges = invoice_json['additional_charges'].reject do |charge, _info|
          charge == 'use_pro_rata'
        end
        charges.transform_values { |amount| BigDecimal(amount.to_s) }
      end
    end

    def use_pro_rata
      @use_pro_rata ||= invoice_json['additional_charges']['use_pro_rata']
    end

    def alerts
      @alerts ||= invoice_json['alert'].map { |alert| alert['desc'] }
    end

    def invoice_notes
      @invoice_notes ||= invoice_json['note'].map do |note|
        { content: note['content'],
          creation_date: note['creation_date'].gsub(/^(.*)Z$/, '\1'),
          creator: note['created_by'] }
      end
    end

    def invoice_lines
      @invoice_lines ||= invoice_json['invoice_lines']['invoice_line'].map do |line|
        ApiInvoiceLine.new(invoice_line: line)
      end
    end
  end
end
