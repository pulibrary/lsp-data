# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'
require 'bigdecimal'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Load in the existing data
lines = []
csv = CSV.open("#{input_dir}/1496_continuous_orders.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  hash = {}
  hash[:mms_id] = row['mmsid']
  hash[:title] = row['title']
  hash[:publisher] = row['pub']
  hash[:pub_date] = row['pub_date']
  hash[:begin_date_f008] = row['beg_pub_date']
  hash[:language] = row['lang_code']
  hash[:pol_fund_code] = row['fund_code']
  hash[:pol_chartstring] = row['fund_external_id']
  hash[:pol] = row['pol']
  pol_create_date = row['pol_date'].gsub(/^([0-9]{4}-[0-9]{2}-[0-9]{2}) .*$/, '\1')
  hash[:pol_create_date] = pol_create_date
  hash[:pol_active_status] = row['pol_stat_act']
  hash[:pol_type] = row['pol_line_type_name']
  hash[:holding_id] = row['hold_id']
  hash[:holding_f866] = row['hold_loc_param1']
  hash[:call_num] = row['perm_call_num']
  hash[:holding_lifecycle] = row['hold_life']
  hash[:item_library] = row['lib_code']
  hash[:item_location] = row['loc_code']
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
File.open("#{output_dir}/1496_continuous_orders_with_invoice_info.tsv", 'w') do |output|
  output.write("MMS ID\tTitle\tPublisher\tPublisher Date\tDate from 008\tLanguage\t")
  output.write("Holding ID\tHolding Lifecyle\tHolding 866\tHolding Call Number\tItem Library\tItem Location\t")
  output.write("POL\tPOL Creation Date\tPOL Type\tPOL Status\tPOL Fund Code\tPOL Chartstring\t")
  output.puts("Total Number of Invoices\tDate of Last Invoice\tNumber of Last Invoice\tFunds Used by Fund Code")
  lines.each do |info|
    pol = info[:pol]
    invoices = pol_invoices[pol]
    last_invoice = invoices.max { |a, b| a.invoice_date <=> b.invoice_date }
    invoice_number = last_invoice&.invoice_number
    invoice_date = last_invoice&.invoice_date&.strftime('%Y-%m-%d')
    invoice_lines = last_invoice&.invoice_lines&.select { |line| line.po_line == pol }
    funds_used = {}
    invoice_lines&.each do |line|
      line.fund_distributions.each do |distro|
        fund_code = distro.fund_code[:code]
        funds_used[fund_code] ||= BigDecimal('0')
        funds_used[fund_code] += distro.amount
      end
    end
    output.write("#{info[:mms_id]}\t")
    output.write("#{info[:title]}\t")
    output.write("#{info[:publisher]}\t")
    output.write("#{info[:pub_date]}\t")
    output.write("#{info[:begin_date_f008]}\t")
    output.write("#{info[:language]}\t")
    output.write("#{info[:holding_id]}\t")
    output.write("#{info[:holding_lifecycle]}\t")
    output.write("#{info[:holding_f866]}\t")
    output.write("#{info[:call_num]}\t")
    output.write("#{info[:item_library]}\t")
    output.write("#{info[:item_location]}\t")
    output.write("#{pol}\t")
    output.write("#{info[:pol_create_date]}\t")
    output.write("#{info[:pol_type]}\t")
    output.write("#{info[:pol_active_status]}\t")
    output.write("#{info[:pol_fund_code]}\t")
    output.write("#{info[:pol_chartstring]}\t")
    output.write("#{invoices.size}\t")
    output.write("#{invoice_date}\t")
    output.write("#{invoice_number}\t")
    output.puts(funds_used.map { |code, amount| "#{code}: #{amount.to_s('F')}" }.join(' | '))
  end
end
