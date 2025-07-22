# frozen_string_literal: true

module LspData
  ### This class makes a connection to a Z39.50 server.
  ### Required elements
  ###   1. Hostname
  ###   2. Port (210 is the default value)
  ###   3. Database name
  ###   4. Element set name (Server-defined code for record contents) ('F' is the default value)
  ### Optional elements
  ###   1. Credentials (hash containing a username and password)
  class Z3950Connection
    attr_reader :connection

    def initialize(host:, database_name:, port: 210, element_set_name: 'F', credentials: nil)
      conn = ZOOM::Connection.new
      conn.database_name = database_name
      conn.element_set_name = element_set_name
      conn.user = credentials[:user] if credentials
      conn.password = credentials[:password] if credentials
      conn.charset = 'UTF-8'
      conn.connect(host, port)
      @connection = conn
    end
  end
end
