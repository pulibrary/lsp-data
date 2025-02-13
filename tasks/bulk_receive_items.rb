# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Load in the POL IDs and item IDs from a report
lines = []
csv = CSV.open("#{input_dir}/one_time_pols_to_receive.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  hash = {}
  hash[:pol] = row['PO Line Reference']
  hash[:title] = row['PO Line Title']
  hash[:vendor_code] = row['Vendor Code']
  hash[:vendor_account] = row['Vendor Account Code']
  hash[:invoice_status] = row['Invoice Status']
  hash[:acq_method] = row['Acquisition Method Description']
  hash[:fund_code] = row['Fund Code']
  hash[:pol_creation_date] = row['PO Line Creation Date (Calendar)']
  hash[:item_id] = row['Physical Item Id']
  lines << hash
end

### Step 2: Attempt to receive each item and log the results
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = LspData.api_conn(url)
api_key = ENV['ALMA_PROD_ACQ_API_KEY']
dept_library = ENV['RECEIVING_DEPT_LIBRARY']
dept = ENV['RECEIVING_DEPT']
responses = {} # hash of item IDs
lines.each do |line|
  receive = PolReceive.new(pol: line[:pol],
                            item_id: line[:item_id],
                            conn: conn,
                            dept_library: dept_library,
                            dept: dept,
                            api_key: api_key)
  responses[line[:item_id]] = { pol: line[:pol], response: receive.response }
end

### Step 3: Write out report
File.open("#{output_dir}/items_autoreceived.tsv", 'w') do |output|
  output.puts("POL\tTitle\tVendor Code\tVendor Account\tInvoice Status\tAcquisition Method\tFund Code\tPOL Creation Date\tItem ID\tBarcode\tMMS ID\tHolding ID\tAPI Status Code\tErrors")
  lines.each do |line|
    response = responses[line[:item_id]]
    output.write("#{line[:pol]}\t")
    output.write("#{line[:title]}\t")
    output.write("#{line[:vendor_code]}\t")
    output.write("#{line[:vendor_account]}\t")
    output.write("#{line[:invoice_status]}\t")
    output.write("#{line[:acq_method]}\t")
    output.write("#{line[:fund_code]}\t")
    output.write("#{line[:pol_creation_date]}\t")
    output.write("#{line[:item_id]}\t")
    case response[:response][:status]
    when 200
      output.write("#{response[:response][:info][:barcode]}\t")
      output.write("#{response[:response][:info][:mms_id]}\t")
      output.write("#{response[:response][:info][:holding_id]}\t")
      output.write("#{response[:response][:status]}\t")
      output.puts('')
    else
      output.write("\t\t\t")
      output.write("#{response[:response][:status]}\t")
      output.puts(response[:response][:info][:errors].join(' | '))
    end
  end
end
