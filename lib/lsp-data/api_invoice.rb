# frozen_string_literal: true

module LspData
  ### This class makes a model of an invoice object returned from Alma via API
  class ApiInvoice
    attr_reader :invoice_json

    def initialize(invoice_json:)
      @invoice_json = invoice_json
    end

    def invoice_number
      @invoice_number ||= invoice_json['number']
    end

    def invoice_date
      @invoice_date ||= begin
                          regex = /^([0-9]{4})\-([0-9]{2})\-([0-9]{2}).*$/
                          date = regex.match(invoice_json['invoice_date'])
                          if date
                            Time.new(date[1].to_i, date[2].to_i, date[3].to_i)
                          end
                        end
    end

    def invoice_total
      @invoice_total ||= BigDecimal(invoice_json['total_amount'].to_s)
    end

    def invoice_lines_total
      @invoice_lines_total ||= BigDecimal(invoice_json['total_invoice_lines_amount'].to_s)
    end

    # Unique Alma invoice identifier
    def pid
      @pid ||= invoice_json['id']
    end

    def reference_number
      @reference_number ||= begin
                              number = invoice_json['reference_number']
                              if number.size.positive?
                                number
                              else
                                nil
                              end
                            end
    end

    def creation_method
      @creation_method ||= invoice_json['creation_form']['desc']
    end

    def status
      @status ||= invoice_json['invoice_status']['desc']
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
                      code: invoice_json['currency']['value'],
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
                          regex = /^([0-9]{4})\-([0-9]{2})\-([0-9]{2}).*$/
                          date = regex.match(invoice_json['payment']['voucher_date'])
                          if date
                            Time.new(date[1].to_i, date[2].to_i, date[3].to_i)
                          end
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
                            if amount
                              BigDecimal(amount.to_s)
                            end
                          end
    end
    def voucher_currency
      @voucher_currency ||= {
                              name: invoice_json['payment']['voucher_currency']['desc'],
                              code: invoice_json['payment']['voucher_currency']['value']
                            }
    end
  end
end
