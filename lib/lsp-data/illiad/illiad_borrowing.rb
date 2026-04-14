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
  ###   TransactionDate [date the transaction entered the current status]
  ###   LendingLibrary
  ###   ISSN (ISSN and ISBN)
  ###   ESPNumber (OCLC number, if SystemID = 'OCLC')
  ###   ILLNumber
  ###   SystemID
  class ILLiadBorrowing
    attr_reader :transaction_number, :username, :creation_date, :transaction_status,
                :transaction_date, :lending_library, :oclc_num, :ill_number, :transaction_info

    def initialize(transaction_info:)
      @transaction_info = transaction_info
      @transaction_number = transaction_info['TransactionNumber'] # Integer
      @username = transaction_info['Username']
      @creation_date = transaction_info['CreationDate'] # Time
      @transaction_status = transaction_info['TransactionStatus']
      @transaction_date = transaction_info['TransactionDate'] # Time
      @lending_library = transaction_info['LendingLibrary']
      @oclc_num = transaction_info['SystemID'] == 'OCLC' ? transaction_info['ESPNumber'] : nil
      @ill_number = transaction_info['ILLNumber']
    end

    ### This could eliminate some potential ISBNs, but it would be quite rare for
    ###   an ISBN to be stored as an 8-digit number, since it would have to be
    ###   a 10-digit ISBN with leading zeroes that were stripped
    def isbn
      @isbn ||= if transaction_info['ISSN'].to_s.gsub(/[^0-9]/, '').size < 9
                  nil
                else
                  isbn_normalize(transaction_info['ISSN'].to_s)
                end
    end

    def issn
      @issn ||= issn_normalize(transaction_info['ISSN'].to_s)
    end
  end
end
