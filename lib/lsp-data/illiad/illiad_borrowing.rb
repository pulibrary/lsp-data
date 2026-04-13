# frozen_string_literal: true

module LspData
  ### This class transforms information retrieved from the ILLiad SQL Server
  ###   related to borrowing. The results are filtered to RequestType = Loan and
  ###   ProcessType = Borrowing
  ### Fields to parse:
  ###   TransactionNumber
  ###   Username
  ###   CreationDate
  ###   TransactionStatus
  ###   TransactionDate
  ###   LendingLibrary
  ###   ISSN (ISSN and ISBN)
  ###   ESPNumber (OCLC number, if SystemID = 'OCLC')
  ###   ILLNumber
  ###   SystemID
  class ILLiadBorrowing
    attr_reader :transaction_number, :username, :creation_date, :transaction_status,
                :transaction_date, :lending_library, :isbn, :issn, :oclc_num, :ill_number

    def initialize(transaction_info)
      @transaction_number = transaction_info['TransactionNumber'] # Integer
      @username = transaction_info['Username']
      @creation_date = transaction_info['CreationDate'] # Time
      @transaction_status = transaction_info['TransactionStatus']
      @transaction_date = transaction_info['TransactionDate'] # Time
      @lending_library = transaction_info['LendingLibrary']
      @isbn = isbn_normalize(transaction_info['ISSN'])
      @issn = issn_normalize(transaction_info['ISSN'])
      @oclc_num = transaction_info['SystemID'] == 'OCLC' ? transaction_info['ESPNumber'] : nil
      @ill_number = transaction_info['ILLNumber']
    end
  end
end
