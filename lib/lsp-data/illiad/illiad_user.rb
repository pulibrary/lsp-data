# frozen_string_literal: true

module LspData
  ### This class transforms information retrieved from the ILLiad SQL Server
  ###   related to user information.
  ### Fields to parse:
  ###   UserName
  ###   LastName
  ###   FirstName
  ###   SSN [patron barcode]
  ###   Status
  ###   Department
  ###   NVTGC
  ###   LastChangedDate
  ###   Site
  ###   ExpirationDate
  ###   Number [primary identifier]
  class ILLiadUser
    attr_reader :username, :last_name, :first_name, :patron_barcode, :status, :department,
                :nvtgc, :modification_date, :site, :expiration_date, :primary_id

    # rubocop:disable Metrics/MethodLength
    def initialize(transaction_info:)
      @username = transaction_info['UserName']
      @last_name = transaction_info['LastName']
      @first_name = transaction_info['FirstName']
      @patron_barcode = transaction_info['SSN']&.gsub(/\s/, ' ')
      @status = transaction_info['Status']
      @department = transaction_info['Department']
      @nvtgc = transaction_info['NVTGC']
      @modification_date = transaction_info['LastChangedDate'] # Time
      @site = transaction_info['Site']
      @expiration_date = transaction_info['ExpirationDate'] # Time
      @primary_id = transaction_info['Number']
    end
    # rubocop:enable Metrics/MethodLength
  end
end
