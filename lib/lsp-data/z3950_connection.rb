# frozen_string_literal: true

### Codebase for parsing LSP data
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

  ### index is a Bib-1 Use Attribute (see https://www.loc.gov/z3950/agency/defns/bib1.html)
  ### nil records are included in results array to allow further action if needed
  def search(index:, identifier:)
    search_string = "@attr 1=#{index} #{identifier}"
    response = connection.search(search_string)
    response.records.map do |result|
      result.nil? ? result : record_from_result(result)
    end
  end

  private

  def record_from_result(result)
    temp_reader = MARC::XMLReader.new(StringIO.new(result.xml, 'r'))
    temp_reader.first
  end
end
