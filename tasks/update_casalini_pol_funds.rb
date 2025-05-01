# frozen_string_literal: true

require_relative './../lib/lsp-data'

### For PO Lines paid and closed that were charged to the wrong fund,
###   update the fund to the correct fund


### Step 1: Retrieve all POLs
api_key = ENV['ALMA_PROD_ACQ_API_KEY']
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = LspData.api_conn(url)

pol_ids = ['POL-454482']
pols = {} # POL ID is the key, POL is the value
pol_ids.each do |pol_id|
  response = ApiRetrievePoLine.new(conn: conn, api_key: api_key, pol_id: pol_id).response
  pols[pol_id] = response
end

### Step 2: Modify the funds in each POL to change which fund is charged
new_fund_code = 'E9994-Arch-no program'
old_fund_code = 'E9995-Art & Arch-no program'
pols.each do |pol_id, get_response|
  next unless get_response[:status] == 200

  pol['fund_distribution'].each do |distribution|
    next unless distribution['fund_code']['value'] == old_fund_code

    distribution['fund_code']['value'] = new_fund_code
  end
end

updated_pols = {}
update_errors = []
### Step 3: Update the POL in Alma
pols.each do |pol_id, get_response|
  next unless get_response[:status] == 200

  response = ApiUpdatePoLine.new(conn: conn, api_key: api_key, pol_id: pol_id, pol: pol).response
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
