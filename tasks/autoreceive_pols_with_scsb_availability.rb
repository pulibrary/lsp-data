# frozen_string_literal: true

### Retrieve SCSB availability for all items from the report of in-place items
###   attached to Sent POLs that are ReCAP items
### Produce a report of POLs that are safe to receive since all associated items are in place
require_relative '../lib/lsp-data'
require 'csv'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

url = ENV.fetch('SCSB_SERVER', nil)
alma_url = 'https://api-na.hosted.exlibrisgroup.com'
scsb_api_key = ENV.fetch('SCSB_AUTH_KEY', nil)
conn = api_conn(url)
alma_conn = api_conn(alma_url)
receiving_library = ENV.fetch('RECEIVING_DEPT_LIBRARY', nil)
receiving_department = ENV.fetch('RECEIVING_DEPT', nil)
alma_api_key = ENV.fetch('ALMA_SANDBOX_ACQ_API_KEY', nil)
recap_locations = %w[recap$pa recap$gp mendel$qk firestone$pf marquand$pv marquand$pj
                     mendel$pk eastasian$pl stokes$pm lewis$pn engineer$pt
                     firestone$pb mudd$ph lewis$ps arch$pw marquand$pz rare$xc
                     rare$xg rare$xm rare$xn rare$xp rare$xr rare$xw rare$xx]
items_per_pol = {}
CSV.open("#{input_dir}/2348 All Items Attached to POLS in Report 6.csv", 'r', encoding: 'bom|utf-8',
                                                                              headers: true).each do |row|
  status = row['Base Status']
  location = "#{row['Library Code']}$#{row['Location Code']}"
  barcode = row['Barcode']
  item_id = row['Physical Item Id']
  holding_id = row['Holdings ID']
  mms_id = row['MMS Id']
  pol = row['PO Line Reference']
  item = { mms_id: mms_id, holding_id: holding_id, item_id: item_id, barcode: barcode }
  items_per_pol[pol] ||= {}
  items_per_pol[pol][:non_recap] ||= []
  items_per_pol[pol][:not_in_place] ||= []
  items_per_pol[pol][:recap_in_place] ||= []
  if !recap_locations.include?(location)
    items_per_pol[pol][:non_recap] << item
  elsif status != 'Item in place'
    items_per_pol[pol][:not_in_place] << item
  else
    items_per_pol[pol][:recap_in_place] << item
  end
end
### Retrieve availability from SCSB for all ReCAP items that are in place
scsb_availability_per_barcode = {}
all_barcodes = items_per_pol.values.map { |item_types| item_types[:recap_in_place].map { |item| item[:barcode] } }
all_barcodes.flatten!
all_barcodes.delete(nil)
all_barcodes.uniq!

all_barcodes.each_slice(30) do |barcodes|
  scsb_response = SCSBItemAvailability.new(barcodes: barcodes, conn: conn, api_key: scsb_api_key).response
  scsb_response[:body].each do |item_response|
    barcode = item_response['itemBarcode']
    status = item_response['itemAvailabilityStatus']
    scsb_availability_per_barcode[barcode] = status
  end
end

### Attempt to receive the ReCAP items via API that are In Place in Alma and in SCSB;
### Document the success or failure for each item in a new array
pol_receiving_status = {}
items_per_pol.each do |pol, item_types|
  next if pol_receiving_status[pol]
  next if item_types[:recap_in_place].empty?

  eligible_to_receive = item_types[:recap_in_place].select do |item|
    !item[:barcode].nil? &&
      scsb_availability_per_barcode[item[:barcode]] != "Item Barcode doesn't exist in SCSB database."
  end
  eligible_to_receive.each do |item|
    receive_response = PolReceive.new(conn: alma_conn, pol: pol, item_id: item[:item_id],
                                      dept_library: receiving_library, dept: receiving_department,
                                      api_key: alma_api_key).response
    pol_receiving_status[pol] ||= {}
    pol_receiving_status[pol][item[:barcode]] = receive_response
  end
end

### Write out report of POLs and items that were successfully updated via API
File.open("#{output_dir}/pols_items_updated_by_api_receive.tsv", 'w') do |output|
  output.puts("POL\tBarcode\tMMS ID\tHolding ID\tItem Library\tItem Location")
  pol_receiving_status.each do |pol, items|
    items.each do |barcode, item|
      next unless item[:status] == 200

      output.write("#{pol}\t")
      output.write("#{barcode}\t#{item[:info][:mms_id]}\t#{item[:info][:holding_id]}\t")
      output.puts("#{item[:info][:item_library]}\t#{item[:info][:item_location]}")
    end
  end
end

### Write out report of all POLs eligible to receive
### Include number of items received via API and total number of items per location
pols_eligible_to_receive = items_per_pol.select do |_pol, item_types|
  item_types[:not_in_place].empty? && item_types[:non_recap].empty? && item_types[:recap_in_place].select do |item|
    !item[:barcode].nil? &&
      scsb_availability_per_barcode[item[:barcode]] != "Item Barcode doesn't exist in SCSB database."
  end.size == item_types[:recap_in_place].size
end
File.open("#{output_dir}/pols_to_receive_in_alma.tsv", 'w') do |output|
  output.puts("PO Line Reference\tNumber of Total Items\tNumber of Items Autoreceived")
  pols_eligible_to_receive.each do |pol, item_types|
    all_items = item_types[:recap_in_place]
    items_received = pol_receiving_status[pol]
    all_barcodes = all_items.map { |item| item[:barcode] }
    all_success = items_received.select { |_barcode, info| info[:status] == 200 }.keys if items_received
    all_success ||= []
    output.write("#{pol}\t")
    output.write("#{all_items.size}\t")
    output.puts(all_success.size)
  end
end
