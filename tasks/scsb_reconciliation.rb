# frozen_string_literal: true

require_relative '../lib/lsp-data'

### The SCSB full dump has the following Alma info:
###   Barcode (876$p)
###   MMS ID (009)
###   Call number (852$h)
###   Customer code (876$z)
###   CGD (876$x)
def extract_scsb_barcode_info(record)
  hash = {}
  record.fields('852').each do |holding_field|
    call_num = holding_field['h']
    holding_id = holding_field['0']
    record.fields('876').select { |field| field['0'] == holding_id }.each do |item_field|
      hash[item_field['p']] = { bib_id: record['009'].value, call_num: call_num, cgd: item_field['x'],
                                customer_code: item_field['z'] }
    end
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
  {
    call_num: [holding_field['h'].to_s, holding_field['i'].to_s].join(' '),
    location: [holding_field['b'], holding_field['c']].join('$'),
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

scsb_barcode_hash = {}
Dir.glob("#{input_dir}/PUL_20260305_151300/*.xml").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic').each do |record|
    scsb_barcode_hash.merge!(extract_scsb_barcode_info(record))
  end
end

all_scsb_barcodes = Set.new(scsb_barcode_hash.keys)
alma_barcode_hash = {}
Dir.glob("#{input_dir}/new_fulldump/*.xml*").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    alma_barcode_hash.merge!(extract_alma_barcode_info(record: record, scsb_barcodes: all_scsb_barcodes))
  end
end

no_alma = File.open("#{output_dir}/scsb_barcodes_not_in_alma.tsv", 'w')
mismatch = File.open("#{output_dir}/scsb_barcodes_alma_mismatch.tsv", 'w')
no_alma.puts("Barcode\tMMS ID in SCSB\tCustomer Code\tCGD\tCall Number")
mismatch.puts("Barcode\tCustomer Code\tCGD\tSCSB Bib ID\tMMS ID\tHolding ID\tItem ID\tAlma Customer Code")
scsb_barcode_hash.each do |barcode, scsb_info|
  all_alma_info = alma_barcode_hash[barcode]
  if all_alma_info
    all_alma_info.each do |item_id, alma_info|
      next unless (scsb_info[:customer_code] != alma_info[:customer_code]) || scsb_info[:bib_id] != alma_info[:bib_id]

      mismatch.write("#{barcode}\t#{scsb_info[:customer_code]}\t#{scsb_info[:cgd]}\t")
      mismatch.write("#{scsb_info[:bib_id]}\t#{alma_info[:bib_id]}\t#{alma_info[:holding_id]}\t")
      mismatch.puts("#{item_id}\t#{alma_info[:customer_code]}")
    end
  else
    no_alma.write("#{barcode}\t#{scsb_info[:bib_id]}\t#{scsb_info[:customer_code]}\t")
    no_alma.puts("#{scsb_info[:cgd]}\t#{scsb_info[:call_num]}")
  end
end

no_alma.close
mismatch.close
