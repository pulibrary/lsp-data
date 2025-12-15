# frozen_string_literal: true

module LspData
  ### This class makes a model of an invoice object returned from Alma via API.
  ###   While it is meant to be a comprehensive model, there are 2 areas that
  ###     are not of interest to PUL: VAT reporting and explicit currency
  ###     conversion ratios. Those areas will not be represented.
  class ApiInvoice
    attr_reader :invoice_json, :status, :alerts, :workflow_status, :approval_status,
                :approver, :owner, :pid, :invoice_number, :voucher_number,
                :creation_method, :use_pro_rata, :invoice_total, :invoice_lines_total

    def initialize(invoice_json:)
      @invoice_json = invoice_json
      status_info
      header_info
      payment_info
    end

    def vendor
      @vendor ||= { name: invoice_json['vendor']['desc'], code: invoice_json['vendor']['value'],
                    account: invoice_json['vendor_account'] }
    end

    def currency
      @currency ||= { name: invoice_json['currency']['desc'], code: invoice_json['currency']['value'] }
    end

    def payment
      @payment ||= {
        prepaid: invoice_json['payment']['prepaid'], internal_copy: invoice_json['payment']['prepaid'],
        payment_status: invoice_json['payment']['payment_status']['desc'],
        payment_method: invoice_json['payment_method']['desc']
      }
    end

    def voucher_date
      @voucher_date ||= begin
        date = date_regex.match(invoice_json['payment']['voucher_date'])
        Time.new(date[1].to_i, date[2].to_i, date[3].to_i) if date
      end
    end

    def calculated_voucher_number
      @calculated_voucher_number ||= begin
        id = pid[2..-6].to_i
        "A#{id.to_s(36).rjust(7, '0')}"
      end
    end

    def voucher_amount
      @voucher_amount ||= amount_or_nil(invoice_json['payment']['voucher_amount'])
    end

    def voucher_currency
      return unless invoice_json['payment']['voucher_currency']['desc']

      @voucher_currency ||= {
        name: invoice_json['payment']['voucher_currency']['desc'],
        code: invoice_json['payment']['voucher_currency']['value']
      }
    end

    def invoice_date
      @invoice_date ||= parse_date(invoice_json['invoice_date'])
    end

    def reference_number
      @reference_number ||= invoice_json['reference_number'] if invoice_json['reference_number'].size.nonzero?
    end

    def approval_date
      @approval_date ||= parse_date(invoice_json['approval_date'])
    end

    def additional_charges
      @additional_charges ||= invoice_json['additional_charges'].except('use_pro_rata')
                                                                .transform_values { |amount| BigDecimal(amount.to_s) }
    end

    def invoice_notes
      @invoice_notes ||= invoice_json['note'].map do |note|
        { content: note['content'], creator: note['created_by'],
          creation_date: note['creation_date'].gsub(/^(.*)Z$/, '\1') }
      end
    end

    def invoice_lines
      @invoice_lines ||= invoice_json['invoice_lines']['invoice_line'].map do |line|
        ApiInvoiceLine.new(invoice_line: line)
      end
    end

    private

    def date_regex
      /^([0-9]{4})-([0-9]{2})-([0-9]{2}).*$/
    end

    def parse_date(raw_date)
      date = date_regex.match(raw_date)
      Time.new(date[1].to_i, date[2].to_i, date[3].to_i) if date
    end

    def amount_or_nil(amount)
      BigDecimal(amount.to_s) if amount.size.nonzero?
    end

    def status_info
      @status = invoice_json['invoice_status']['desc']
      @alerts = invoice_json['alert'].map { |alert| alert['desc'] }
      @workflow_status = invoice_json['invoice_workflow_status']['desc']
      @approval_status = invoice_json['invoice_approval_status']['desc']
      @approver = invoice_json['approved_by']
    end

    def header_info
      @owner = invoice_json['owner']['value']
      @pid = invoice_json['id'] # Unique Alma invoice identifier
      @invoice_number = invoice_json['number']
      @creation_method = invoice_json['creation_form']['desc']
    end

    def payment_info
      @voucher_number = invoice_json['payment']['voucher_number']
      @use_pro_rata = invoice_json['additional_charges']['use_pro_rata']
      @invoice_total = BigDecimal(invoice_json['total_amount'].to_s)
      @invoice_lines_total = BigDecimal(invoice_json['total_invoice_lines_amount'].to_s)
    end
  end
end
