# frozen_string_literal: true

FIXTURE_DIR = File.join(File.dirname(__FILE__), '../fixtures/files')
def stub_invoice_query(query:, fixture:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:get, "https://api-na.exlibrisgroup.com/almaws/v1/acq/invoices/?limit=100&q=#{query}")
    .to_return(status: 200, body: data)
end
