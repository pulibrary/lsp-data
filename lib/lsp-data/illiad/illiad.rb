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

    def all_loan_borrowing
      conn.execute(loan_borrowing_query).map { |row| ILLiadBorrowing.new(transaction_info: row) }
    end

    def all_article_borrowing
      conn.execute(article_borrowing_query).map { |row| ILLiadBorrowing.new(transaction_info: row) }
    end

    def all_users
      conn.execute(user_query).map { |row| ILLiadUser.new(transaction_info: row) }
    end

    private

    # rubocop:disable Metrics/MethodLength
    def loan_borrowing_query
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
      ORDER BY TransactionNumber
      )
    end

    def article_borrowing_query
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
          AND RequestType = 'Article'
          AND ProcessType IN ('Borrowing', 'DocDel')
      ORDER BY TransactionNumber
      )
    end
    # rubocop:enable Metrics/MethodLength

    def user_query
      %(
        SELECT
          UserName,
          LastName,
          FirstName,
          SSN,
          Status,
          Department,
          NVTGC,
          LastChangedDate,
          Site,
          ExpirationDate,
          Number
        FROM UsersALL
      )
    end
  end
end
