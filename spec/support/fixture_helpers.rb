# frozen_string_literal: true

FIXTURE_DIR = File.join(File.dirname(__FILE__), '../fixtures/files')
def stub_invoice_query(query:, fixture:, offset: 0)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:get, "https://api-na.exlibrisgroup.com/almaws/v1/acq/invoices/?limit=100&q=#{query}&offset=#{offset}&apikey=apikey")
    .to_return(status: 200, body: data)
end

def stub_json_fixture(fixture:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  JSON.parse(data)
end
