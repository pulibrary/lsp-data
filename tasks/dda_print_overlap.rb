# frozen_string_literal: true

### Given a list of records purchased through JSTOR DDA, find print monographs
###   from PUL and the ReCAP partners that match the titles;
### Report the matches from each partner in separate columns

require_relative '../lib/lsp-data'
require 'csv'

def print_locations(record)
  f852 = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
  f852.map { |field| "#{field['b']}$#{field['c']}" }.uniq
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Import the MMS IDs from the Selector Dashboard expenditure report for expenditures
###   on the 3110-55 YBP account
dda_ids = Set.new
csv = CSV.open("#{input_dir}/ybp_fy26.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  next unless row['Vendor Account Code'] == '3110-55'

  dda_ids << row['MMS Id'] unless row['MMS Id'] == '-1'
end

### Go through a full dump of PUL; if the MMS ID matches the DDA IDs, add that MMS ID
###   to a hash with the match key as the key; if the record is a monograph with print inventory, add that MMS ID
###   to a hash with the match key; also maintain a hash of print locations associated with each print bib

key_to_ids = {}
id_to_location = {}
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    mms_id = record['001'].value
    locations = print_locations(record)
    if dda_ids.include?(mms_id)
      key = MarcMatchKey::Key.new(record).key[0..-2] # exclude electronic indicator
      key_to_ids[key] ||= {}
      key_to_ids[key][:dda] ||= []
      key_to_ids[key][:dda] << mms_id
    elsif locations.size.nonzero? && record.leader[7] == 'm' && record.leader[5] != 'd'
      key = MarcMatchKey::Key.new(record).key[0..-2]
      key_to_ids[key] ||= {}
      key_to_ids[key][:pul_print] ||= []
      key_to_ids[key][:pul_print] << mms_id
      id_to_location[mms_id] = locations
    end
  end
end

### We only care about match keys with a DDA MMS ID
key_to_ids.delete_if { |_key, ids| ids[:dda].nil? }
all_pul_matches = []
key_to_ids.each_value do |ids|
  ids[:pul_print]&.each { |id| all_pul_matches << id }
end
id_to_location.select! { |id, _locations| all_pul_matches.include?(id) }

### Go through ReCAP partner shared records; if the record's match key matches with a DDA key,
###   and the record is a monograph, add the ID to the match key hash
Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless record.leader[7] == 'm'

    key = MarcMatchKey::Key.new(record).key[0..-2]
    next unless key_to_ids[key]

    id = record['001'].value
    key_to_ids[key][:cul] ||= []
    key_to_ids[key][:cul] << id
  end
end

Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless record.leader[7] == 'm'

    key = MarcMatchKey::Key.new(record).key[0..-2]
    next unless key_to_ids[key]

    id = record['001'].value
    key_to_ids[key][:hl] ||= []
    key_to_ids[key][:hl] << id
  end
end

Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless record.leader[7] == 'm'

    key = MarcMatchKey::Key.new(record).key[0..-2]
    next unless key_to_ids[key]

    id = record['001'].value
    key_to_ids[key][:nypl] ||= []
    key_to_ids[key][:nypl] << id
  end
end

### Write out the dashboard report, filtering to JSTORDDA purchases
output = File.open("#{output_dir}/jstordda_fy26_print_overlap.tsv", 'w')
output.write("PO Line Reference\tPO Line Title\tFund Code\tFund External Id\tPOL Net Price\t")
output.write("PO Line Notes\tVendor Code\tVendor Account Code\tVendor Account Description\t")
output.write("Invoice-Number\tInvoice-Date\tInvoice-Creation Date\tInvoice Line-Unique Identifier\t")
output.write("Invoice Line Total Price\tTransaction Amount (USD)\tTransaction Date\t")
output.write("Subjects\tJSTOR DDA MMS ID\tISBN (Normalized)\tOCLC Control Number (035a)\tPublication Place\t")
output.write("Publisher\tPublication Date\tLanguage Code\tLC Classification Top Line\t")
output.puts("Any Match?\tPUL Print IDs\tPUL Print Locations\tCUL Shared\tHL Shared\tNYPL Shared")
csv = CSV.open("#{input_dir}/ybp_fy26.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  next unless row['Vendor Account Code'] == '3110-55'

  dda_id = row['MMS Id']
  key_matches = key_to_ids.select { |_key, ids| ids[:dda].include?(dda_id) }.values.first
  pul_matches = key_matches[:pul_print].to_a
  cul_matches = key_matches[:cul].to_a
  hl_matches = key_matches[:hl].to_a
  nypl_matches = key_matches[:nypl].to_a
  has_match = (pul_matches + cul_matches + hl_matches + nypl_matches).size.positive?
  locations = id_to_location.slice(*pul_matches).values.flatten.uniq.sort
  output.write("#{row['PO Line Reference']}\t#{row['PO Line Title']}\t#{row['Allocated Fund']}\t")
  output.write("#{row['Fund External Id']}\t#{row['POL Net Price']}\t#{row['PO Line Notes']}\t")
  output.write("#{row['Vendor Code']}\t#{row['Vendor Account Code']}\t#{row['Vendor Account Description']}\t")
  output.write("#{row['Invoice-Number']}\t#{row['Invoice-Date']}\t#{row['Invoice-Creation Date']}\t")
  output.write("#{row['Invoice Line-Unique Identifier']}\t#{row['Invoice Line Total Price']}\t")
  output.write("#{row['Transaction Amount (USD)']}\t#{row['Transaction Date']}\t")
  output.write("#{row['Subjects']}\t#{dda_id}\t#{row['ISBN (Normalized)']}\t")
  output.write("#{row['OCLC Control Number (035a)']}\t#{row['Publication Place']}\t")
  output.write("#{row['Publisher']}\t#{row['Publication Date']}\t#{row['Language Code']}\t")
  output.write("#{row['LC Classification Top Line']}\t")
  output.write("#{has_match}\t")
  output.write("#{pul_matches.join(' | ')}\t#{locations.join(' | ')}\t")
  output.puts("#{cul_matches.join(' | ')}\t#{hl_matches.join(' | ')}\t#{nypl_matches.join(' | ')}")
end
output.close
