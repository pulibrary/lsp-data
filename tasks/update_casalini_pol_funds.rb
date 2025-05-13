# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

### For PO Lines paid and closed that were charged to the wrong fund,
###   update the fund to the correct fund

### Step 1: Retrieve all POLs
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

api_key = ENV['ALMA_PROD_ACQ_API_KEY']
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = LspData.api_conn(url)

pol_ids = []
csv = CSV.open("#{input_dir}/1697 Casalini Architecture Fund.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  pol_id = row['PO Line Reference']
  pol_ids << pol_id
end

pols = {} # POL ID is the key, POL is the value
pol_ids.each do |pol_id|
  pols[pol_id] = ApiRetrievePoLine.new(conn: conn, api_key: api_key, pol_id: pol_id).response
end

### Step 2: Modify the funds in each POL to change which fund is charged
new_fund_code = 'E9994-Arch-no program'
old_fund_code = 'E9995-Art & Arch-no program'
pols_to_change = {}
pols.each do |pol_id, get_response|
  to_change = false
  next unless get_response[:status] == 200

  pol = get_response[:body].dup
  pol['fund_distribution'].each do |distribution|
    next unless distribution['fund_code']['value'] == old_fund_code

    distribution['fund_code']['value'] = new_fund_code
    to_change = true
  end
  pols_to_change[pol_id] = pol if to_change
end

updated_pols = {}
### Step 3: Update the POL in Alma
pols_to_change.each do |pol_id, pol|
  next if updated_pols[pol_id]

  response = ApiUpdatePoLine.new(conn: conn, api_key: api_key, pol: pol, redistribute_funds: true).response
  updated_pols[pol_id] = response
end

### Step 4: Write out report
File.open("#{output_dir}/casalini_pol_funds_update.tsv", 'w') do |output|
  output.puts("PO Line Reference\tRetrieval Response\tUpdate Response")
  pol_ids.each do |pol_id|
    get_response = pols[pol_id]
    update_response = updated_pols[pol_id]
    output.write("#{pol_id}\t")
    output.write("#{get_response[:status]}\t")
    if update_response
      output.puts(update_response[:status])
    else
      output.puts('')
    end
  end
end
