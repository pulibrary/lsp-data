# frozen_string_literal: true

module LspData
  ### This class retrieves information from ILLiad and transforms it into an array of objects.
  ### An ILLiad connection is created upon instantiating the class
  class ILLiad
    attr_reader :conn

    def initialize(tds_client_class: TinyTds::Client, credentials: { username: ILLIAD_USER, password: ILLIAD_PASS,
                                                                     host: ILLIAD_HOST, database: ILLIAD_DB })
      @conn = tds_client_class.new(credentials)
    end

    def all_borrowing
      conn.execute(borrowing_query).map { |row| ILLiadBorrowing.new(row) }
    end

    private

    # rubocop:disable Metrics/MethodLength
    def borrowing_query
      %(
        SELECT
          TransactionNumber,
          RequestType,
          Username,
          CreationDate,
          TransactionStatus,
          TransactionDate,
          ProcessType,
          LendingLibrary,
          ISSN,
          ESPNumber,
          ILLNumber,
          SystemID
      FROM Transactions
      WHERE
          TransactionStatus != 'Cancelled by ILL Staff'
          AND RequestType = 'Loan'
          AND ProcessType = 'Borrowing'
          AND LendingLibrary = ?
      ORDER BY TransactionNumber
      )
    end
    # rubocop:enable Metrics/MethodLength
  end
end
