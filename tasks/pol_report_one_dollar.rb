# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'
require 'bigdecimal'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

def funds_on_invoice_lines(invoice_lines)
  funds = {}
  invoice_lines.each do |line|
    line.fund_distributions.each do |distro|
      fund_code = distro.fund_code[:code]
      funds[fund_code] ||= BigDecimal('0')
      funds[fund_code] += distro.amount
    end
  end
  funds
end

def last_invoice_info(invoices:, pol:)
  return if invoices.empty?

  last_invoice = invoices.max { |a, b| a.invoice_date <=> b.invoice_date }
  invoice_number = last_invoice.invoice_number
  invoice_date = last_invoice.invoice_date.strftime('%Y-%m-%d')
  invoice_lines = last_invoice.invoice_lines.select { |line| line.po_line == pol }
  funds = funds_on_invoice_lines(invoice_lines)
  { funds: funds, invoice_number: invoice_number, invoice_date: invoice_date }
end

### Step 1: Load in the existing data
lines = []
csv = CSV.open("#{input_dir}/1644 Print Continuations 1 Dollar.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  hash = {}
  hash[:pol] = row['PO Line Reference']
  hash[:po_number] = row['PO Number']
  hash[:title] = row['PO Line Title']
  hash[:pol_type] = row['Order Line Type']
  hash[:pol_status] = row['Status (Active)']
  hash[:pol_sent_date] = row['Sent Date']
  hash[:reporting_code] = row['Reporting Code Description - 1st']
  hash[:acq_method] = row['Acquisition Method Description']
  hash[:vendor_code] = row['Vendor Code']
  hash[:vendor_account_code] = row['Vendor Account Code']
  hash[:currency] = row['Currency']
  hash[:list_price] = BigDecimal(row['List Price'])
  hash[:invoice_status] = row['Invoice Status']
  lines << hash
end

### Step 2: Retrieve invoices via API for each POL
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = LspData.api_conn(url)
api_key = ENV['ALMA_PROD_ACQ_API_KEY']
all_pols = lines.map { |line| line[:pol] }.uniq
pol_invoices = {}
all_pols.each do |pol|
  next if pol_invoices[pol]

  invoice_list = ApiPolInvoiceList.new(pol: pol, conn: conn, api_key: api_key)
  pol_invoices[pol] = invoice_list.invoices
end

### Step 3: Write out report
File.open("#{output_dir}/one_dollar_pols_with_invoice_info_test.tsv", 'w') do |output|
  output.write("POL\tPO Number\tTitle\tPOL Type\tPOL Status\tSent Date\tReporting Code\tAcquisition Method\t")
  output.write("Vendor Code\tVendor Account Code\tCurrency\tList Price\tPOL Invoice Status\t")
  output.puts("Total Number of Invoices\tDate of Last Invoice\tNumber of Last Invoice\tFunds Used On Last Invoice")
  lines.each do |info|
    pol = info[:pol]
    invoices = pol_invoices[pol]
    last_invoice = last_invoice_info(invoices: invoices, pol: pol)
    output.write("#{pol}\t")
    output.write("#{info[:po_number]}\t")
    output.write("#{info[:title]}\t")
    output.write("#{info[:pol_type]}\t")
    output.write("#{info[:pol_status]}\t")
    output.write("#{info[:pol_sent_date]}\t")
    output.write("#{info[:reporting_code]}\t")
    output.write("#{info[:acq_method]}\t")
    output.write("#{info[:vendor_code]}\t")
    output.write("#{info[:vendor_account_code]}\t")
    output.write("#{info[:currency]}\t")
    output.write("#{info[:list_price].to_s('F')}\t")
    output.write("#{info[:invoice_status]}\t")
    output.write("#{invoices.size}\t")
    if last_invoice
      output.write("#{last_invoice[:invoice_date]}\t")
      output.write("#{last_invoice[:invoice_number]}\t")
      output.puts(last_invoice[:funds].map { |code, amount| "#{code}: #{amount.to_s('F')}" }.join(' | '))
    else
      output.puts('')
    end
  end
end
