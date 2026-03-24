# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'csv'

### The LAS `if` table contains all barcodes ever accessioned into ReCAP
### Relevant fields for reconciling with LAS and Alma:
###   - Item BarCode
###   - Owner (ReCAP customer code)
###   - Accession date
###   - Date Withdrawn [question mark if not withdrawn]

def extract_las_barcodes(file:, customer_codes:)
  hash = {}
  CSV.open(file, 'r', headers: true).each do |row|
    next unless customer_codes.include?(row['Owner'])

    accession_date = row['Accession Date'] == '?' ? nil : Date.strptime(row['Accession Date'], '%m/%d/%y')
    withdrawal_date = row['Date Withdrawn'] == '?' ? nil : Date.strptime(row['Date Withdrawn'], '%m/%d/%y')
    hash[row['Item BarCode']] = { customer_code: row['Owner'], accession_date: accession_date,
                                  withdrawal_date: withdrawal_date }
  end
  hash
end

def location_to_customer_code
  {
    'arch$pw' => 'PW', 'eastasian$pl' => 'PL', 'eastasian$ql' => 'QL', 'engineer$pt' => 'PT',
    'firestone$pb' => 'PB', 'firestone$pf' => 'PF', 'lewis$pn' => 'PN', 'lewis$ps' => 'PS',
    'marquand$pj' => 'PJ', 'marquand$pz' => 'PZ', 'marquand$pv' => 'PV', 'marquand$pjm' => 'PJ',
    'mendel$pk' => 'PK', 'mendel$qk' => 'QK', 'mudd$ph' => 'PH', 'mudd$phr' => 'PH',
    'recap$pq' => 'PQ', 'recap$pa' => 'PA', 'recap$gp' => 'GP', 'recap$qv' => 'QV',
    'recap$jq' => 'JQ', 'recap$pe' => 'PE', 'rare$xc' => 'PG', 'rare$xg' => 'PG', 'rare$xm' => 'PG',
    'rare$xn' => 'PG', 'rare$xp' => 'PG', 'rare$xr' => 'PG', 'rare$xw' => 'PG', 'rare$xx' => 'PG',
    'rare$xmr' => 'PG', 'rare$xcr' => 'PG', 'rare$xgr' => 'PG', 'rare$xrr' => 'PG', 'stokes$pm' => 'PM'
  }
end

def relevant_items(record, scsb_barcodes)
  record.fields('876').select do |field|
    field['0'] =~ /^22[0-9]+6421$/ && scsb_barcodes.include?(field['p']&.strip)
  end
end

def alma_item_info(item_field)
  {
    holding_id: item_field['0'],
    barcode: item_field['p'].strip,
    item_id: item_field['a']
  }
end

def alma_holding_info(record, holding_id)
  holding_field = record.fields('852').find { |field| field['8'] == holding_id }
  location = [holding_field['b'], holding_field['c']].join('$')
  {
    call_num: [holding_field['h'].to_s, holding_field['i'].to_s].join(' '),
    location: location,
    customer_code: location_to_customer_code[location].to_s
  }
end

def alma_info_hash(mms_id:, holding_info:, item_info:)
  {
    bib_id: mms_id,
    holding_id: item_info[:holding_id],
    call_num: holding_info[:call_num],
    location: holding_info[:location],
    customer_code: holding_info[:customer_code]
  }
end

def extract_alma_barcode_info(record:, scsb_barcodes:)
  hash = {}
  mms_id = record['001'].value
  relevant_items(record, scsb_barcodes).each do |item_field|
    item_info = alma_item_info(item_field)
    holding_info = alma_holding_info(record, item_info[:holding_id])
    hash[item_info[:barcode]] ||= {}
    hash[item_info[:barcode]][item_info[:item_id]] =
      alma_info_hash(mms_id: mms_id, holding_info: holding_info, item_info: item_info)
  end
  hash
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

file = "#{input_dir}/LAS Tables/table260318.full.if.csv"
pul_customer_codes = Set.new(%w[PA PB PE PF PG PH PJ PK PL PM PN PQ PS PT PV PW PZ QA QC QD QK QL QP QT QV GP JQ QX])
las_barcode_hash = extract_las_barcodes(file: file,
                                        customer_codes: pul_customer_codes)

all_las_barcodes = Set.new(las_barcode_hash.keys)
alma_barcode_hash = {}
Dir.glob("#{input_dir}/new_fulldump/*.xml*").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    alma_barcode_hash.merge!(extract_alma_barcode_info(record: record, scsb_barcodes: all_las_barcodes))
  end
end

status = File.open("#{output_dir}/las_barcodes_different_status.tsv", 'w')
mismatch = File.open("#{output_dir}/las_barcodes_alma_mismatch.tsv", 'w')
status.write("Barcode\tAccession Date\tWithdrawal Date\tCustomer Code\t")
status.puts("MMS ID\tHolding ID\tItem ID\tAlma Location Code\tAlma Customer Code")
mismatch.write("Barcode\tAccession Date\tWithdrawal Date\tLAS Customer Code\t")
mismatch.puts("MMS ID\tHolding ID\tItem ID\tAlma Location Code\tAlma Customer Code")
las_barcode_hash.each do |barcode, las_info|
  all_alma_info = alma_barcode_hash[barcode]
  if all_alma_info && las_info[:withdrawal_date]
    all_alma_info.each do |item_id, alma_info|
      status.write("#{barcode}\t#{las_info[:accession_date]}\t#{las_info[:withdrawal_date]}\t")
      status.write("#{las_info[:customer_code]}\t#{alma_info[:bib_id]}\t#{alma_info[:holding_id]}\t")
      status.puts("#{item_id}\t#{alma_info[:location]}\t#{alma_info[:customer_code]}")
    end
  elsif all_alma_info
    all_alma_info.each do |item_id, alma_info|
      next unless las_info[:customer_code] != alma_info[:customer_code]

      mismatch.write("#{barcode}\t#{las_info[:accession_date]}\t#{las_info[:withdrawal_date]}\t")
      mismatch.write("#{las_info[:customer_code]}\t#{alma_info[:bib_id]}\t#{alma_info[:holding_id]}\t")
      mismatch.puts("#{item_id}\t#{alma_info[:location]}\t#{alma_info[:customer_code]}")
    end
  elsif las_info[:withdrawal_date].nil?
    status.write("#{barcode}\t#{las_info[:accession_date]}\t#{las_info[:withdrawal_date]}\t")
    status.puts("#{las_info[:customer_code]}\t\t\t\t\t")
  end
end
status.close
mismatch.close
