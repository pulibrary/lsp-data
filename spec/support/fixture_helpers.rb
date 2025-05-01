# frozen_string_literal: true

FIXTURE_DIR = File.join(File.dirname(__FILE__), '../fixtures/files')
def stub_invoice_query(query:, fixture:, offset: 0)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:get, "https://api-na.exlibrisgroup.com/almaws/v1/acq/invoices/?limit=100&q=#{query}&offset=#{offset}&apikey=apikey")
    .to_return(status: 200, body: data)
end

def stub_receive_response(pol:, item_id:, fixture:, status:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  params = "apikey=apikey&op=receive&department=dept&department_library=lib"
  url = "https://api-na.exlibrisgroup.com/almaws/v1/acq/po-lines/#{pol}/items/#{item_id}?#{params}"
  stub_request(:post, url).
    with(body: { }.to_json, headers: {
      'Accept' => 'application/json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Content-Type' => 'application/json',
      'User-Agent' => 'Faraday v1.10.4' }).
    to_return(status: status, body:data)
end

def stub_get_portfolio_response(mms_id:, portfolio_id:, fixture:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:get, "https://api-na.exlibrisgroup.com/almaws/v1/bibs/#{mms_id}/portfolios/#{portfolio_id}?apikey=apikey")
    .to_return(status: 200, body: data)
end

def stub_get_po_line_response(pol_id:, fixture:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:get, "https://api-na.exlibrisgroup.com/almaws/v1/acq/po-lines/#{pol_id}?apikey=apikey")
    .to_return(status: 200, body: data)
end

def stub_put_portfolio_response(mms_id:, portfolio_id:, fixture:, status:)
  body = stub_json_fixture(fixture: fixture)
  url = "https://api-na.exlibrisgroup.com/almaws/v1/bibs/#{mms_id}/portfolios/#{portfolio_id}?apikey=apikey"
  stub_request(:put, url)
    .with(body: body.to_json, headers: {
      'Accept' => 'application/json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Content-Type' => 'application/json',
      'User-Agent' => 'Faraday v1.10.4' })
    .to_return(status: status, body: body.to_json)
end

def stub_oauth(fixture:, url:, scope:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:post, "#{url}?grant_type=client_credentials&scope=#{scope}").
    with(headers: {
      'Accept' => 'application/json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => 'Basic aWQ6c2VjcmV0',
      'Content-Length' => '0',
      'User-Agent' => 'Faraday v1.10.4' }).
    to_return(status: 200, body: data)
end

def stub_oclc(fixture:, url:, token:, oclc_num:, desired_status:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:get, "#{url}/manage/bibs/#{oclc_num}").
    with(headers: {
      'Accept' => 'application/marcxml+xml',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json',
      'User-Agent' => 'Faraday v1.10.4'
      }).
    to_return(status: desired_status, body: data)
end

def stub_unset(fixture:, url:, token:, oclc_num:, desired_status:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  stub_request(:post, "#{url}/manage/institution/holdings/#{oclc_num}/unset").
    with(headers: {
      'Accept' => 'application/json',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json',
      'User-Agent' => 'Faraday v1.10.4'
      }).
    to_return(status: desired_status, body: data)
end

def stub_json_fixture(fixture:)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  data = File.read(file)
  JSON.parse(data)
end

def stub_bib_record(fixture)
  file = File.open("#{FIXTURE_DIR}/#{fixture}")
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.first
end
