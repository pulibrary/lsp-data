# frozen_string_literal: true

### Find monographic works where Princeton patrons have access to print and
###   electronic versions;
### For PUL items, creation date of the bib record is 7/1/23 or earlier
### For partner shared ReCAP items, accession date of the item is 7/1/23 or earlier

require_relative './../lib/lsp-data'
require 'csv'
require 'bigdecimal'

def preferred_call_num(call_nums)
  return call_nums[:holdings].first[1].first unless call_nums[:holdings].empty?
  return call_nums[:f050].first unless call_nums[:f050].empty?

  call_nums[:f090].first unless call_nums[:f090].empty?
end

def electronic_collections(record)
  f951 = record.fields('951').select { |field| field['0'] =~ /6421$/ }
  f951.map { |field| { coverage: field['k'], collection: field['n'] } }
end

def format_collections(electronic_collections)
  array = []
  electronic_collections.each do |electronic_collection|
    string = ''.dup
    string << electronic_collection[:collection] if electronic_collection[:collection]
    string << ": #{electronic_collection[:coverage]}" if electronic_collection[:coverage].to_s != ''
    array << string.gsub(/^: (.*)$/, '\1') if string.size.positive?
  end
  array.uniq.join(' | ')
end

def print_locations(record)
  f852 = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
  f852.map { |field| "#{field['b']}$#{field['c']}" }.uniq
end

def total_usage_per_group(match_info)
  hash = {}
  match_info[:pul_loans].each do |group, usage|
    hash[group] ||= BigDecimal('0')
    hash[group] += usage
  end
  match_info[:partner_loans].each do |group, usage|
    hash[group] ||= BigDecimal('0')
    hash[group] += usage
  end
  hash
end

def write_partner_key_info(record:, output:, recap_accessions:, electronic_match_keys:)
  bc_matches = record.fields('876').select { |f| recap_accessions.include?(f['p']) }
  return if bc_matches.empty?

  key = MarcMatchKey::Key.new(record).key[0..-2]
  return unless electronic_match_keys.include?(key)

  bc_matches.each do |field|
    output.write("#{record['001'].value}\t")
    output.write("#{field['p']}\t")
    output.puts(key)
  end
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Create a file of all barcodes accessioned into ReCAP 7/1/23 or earlier
File.open("#{output_dir}/recap_accessions_fy23_before.txt", 'w') do |output|
  output.puts('barcode')
  CSV.open("#{input_dir}/LAS Tables/table250919.full.if.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
    csv.each do |row|
      accession_date = DateTime.strptime(row['Accession Date'], '%m/%d/%y')
      next if accession_date > DateTime.strptime('07-01-2023', '%m-%d-%Y')

      output.puts(row['Item BarCode'])
    end
  end
end

### Find all PUL bibs with only electronic inventory created before 7/1/23;
### an Analytics report will contain the MMS IDs; load in the IDs as a set
electronic_ids = Set.new
File.open("#{input_dir}/ebook_mms_ids.csv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    electronic_ids << line
  end
end

### Output the match keys for the electronic bibs for further use in identifying
###   overlapping bibs; also output the ISBNs; ignore the print/electronic indicator in the key
isbn_out = File.open("#{output_dir}/ebook_isbns.tsv", 'w')
isbn_out.puts("mms_id\tisbn")
File.open("#{output_dir}/ebook_match_keys.tsv", 'w') do |output|
  output.puts("MMS ID\tMatch Key")
  Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
    reader.each do |record|
      mms_id = record['001'].value
      next unless electronic_ids.include?(mms_id)

      output.write("#{mms_id}\t")
      output.puts(MarcMatchKey::Key.new(record).key[0..-2])
      isbns(record).each do |isbn|
        isbn_out.write("#{mms_id}\t")
        isbn_out.puts(isbn)
      end
    end
  end
end
isbn_out.close
electronic_ids.clear

### Go through the full dump, looking for records with the following conditions:
###   1. Has at least one item
###   2. Is a monograph
###   3. Is textual material
###   4. Bib create date is created before 7/1/23
###   5. Has match key that matches the electronic keys
### Output the MMS ID and match key
electronic_match_keys = Set.new
File.open("#{input_dir}/ebook_match_keys.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    electronic_match_keys << parts[1] # ignore print vs. electronic indicator
  end
end

File.open("#{output_dir}/print_bibs_electronic_match.tsv", 'w') do |output|
  output.puts("MMS ID\tMatch Key")
  Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
    reader.each do |record|
      next unless record.leader[6..7] == 'am'

      has_item = record.fields('876').any? { |f| f['0'] =~ /^22[0-9]+6421$/ && f['a'] =~ /^23[0-9]+6421$/ }
      next unless has_item

      bib_info = record.fields('950').find do |field|
        %w[true false].include?(field['a']) &&
          field['b'] =~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/
      end
      create_date = bib_info['b'].gsub(/^([0-9]{4}-[0-9]{2}-[0-9]{2}) .*$/, '\1')
      next unless DateTime.strptime(create_date, '%Y-%m-%d') < DateTime.new(2023, 7, 1)

      key = MarcMatchKey::Key.new(record).key[0..-2] # ignore print vs. electronic indicator
      if electronic_match_keys.include?(key)
        output.write("#{record['001'].value}\t")
        output.puts(key)
      end
    end
  end
end

### Go through ReCAP shared partner records; if the record has a barcode that was accessioned
###   before 7/1/23, and the record is a monograph, check if the match key matches
recap_accessions = Set.new
File.open("#{input_dir}/recap_accessions_fy23_before.txt", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    recap_accessions << line
  end
end

File.open("#{output_dir}/cul_ebook_match.tsv", 'w') do |output|
  output.puts("Bib ID\tBarcode\tMatch Key")
  Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless record.leader[6..7] == 'am'

      write_partner_key_info(record: record,
                             output: output,
                             recap_accessions: recap_accessions,
                             electronic_match_keys: electronic_match_keys)
    end
  end
end

File.open("#{output_dir}/hl_ebook_match.tsv", 'w') do |output|
  output.puts("Bib ID\tBarcode\tMatch Key")
  Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      write_partner_key_info(record: record,
                             output: output,
                             recap_accessions: recap_accessions,
                             electronic_match_keys: electronic_match_keys)
    end
  end
end

File.open("#{output_dir}/nypl_ebook_match.tsv", 'w') do |output|
  output.puts("Bib ID\tBarcode\tMatch Key")
  Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      write_partner_key_info(record: record,
                             output: output,
                             recap_accessions: recap_accessions,
                             electronic_match_keys: electronic_match_keys)
    end
  end
end

### Make a hash with the match key as the key and IDs from each source as values
match_to_ids = {}
File.open("#{input_dir}/ebook_match_keys.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    key = parts[1][0..-2]
    match_to_ids[key] ||= { ebook: [] }
    match_to_ids[key][:ebook] << mms_id
  end
end

File.open("#{input_dir}/print_bibs_electronic_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    key = parts[1]
    next unless match_to_ids[key]

    match_to_ids[key][:pul_print] ||= []
    match_to_ids[key][:pul_print] << mms_id
  end
end

File.open("#{input_dir}/cul_ebook_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    key = parts[2]
    next unless match_to_ids[key]

    match_to_ids[key][:cul] ||= []
    match_to_ids[key][:cul] << mms_id
  end
end

File.open("#{input_dir}/hl_ebook_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    key = parts[2]
    next unless match_to_ids[key]

    match_to_ids[key][:hl] ||= []
    match_to_ids[key][:hl] << mms_id
  end
end

File.open("#{input_dir}/nypl_ebook_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    key = parts[2]
    next unless match_to_ids[key]

    match_to_ids[key][:nypl] ||= []
    match_to_ids[key][:nypl] << mms_id
  end
end

### We only care about match keys that have an ebook and at least one print copy
match_to_ids.delete_if { |_key, sites| sites.size < 2 }

all_pul_ids = Set.new
match_to_ids.each_value do |sites|
  sites[:ebook].each { |id| all_pul_ids << id }
  sites[:pul_print]&.each { |id| all_pul_ids << id }
end

### Retrieve LC call numbers, electronic collection names, and PUL print locations
###   from PUL Print and Electronic records for keys with more than one site
bib_info = {} # MMS ID is the key
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    mms_id = record['001'].value
    next unless all_pul_ids.include?(mms_id)

    hash = {}
    hash[:lc_call_nums] = all_call_nums_from_merged_bib(record: record, inst_suffix: '6421')
    hash[:electronic_collections] = electronic_collections(record)
    hash[:print_locations] = print_locations(record)
    bib_info[mms_id] = hash
  end
end

### Retrieve a report of all MMS IDs that had print usage in FY24 through FY25;
bib_loans = {}
CSV.open("#{input_dir}/usage_all_mms_ids_fy24-fy25_user_group.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    mms_id = row['MMS Id']
    next unless all_pul_ids.include?(mms_id)

    bib_loans[mms_id] ||= {
      'P Faculty & Professional' => BigDecimal('0'),
      'GRAD Graduate Student' => BigDecimal('0'),
      'UGRD Undergraduate' => BigDecimal('0'),
      'SENR Senior Undergraduate' => BigDecimal('0'),
      'REG Regular Staff' => BigDecimal('0'),
      'GST Guest Patron' => BigDecimal('0'),
      'CAR1 Carrel 1' => BigDecimal('0'),
      'Affiliate' => BigDecimal('0'),
      'Affiliate-P Faculty Affiliate' => BigDecimal('0'),
      'CAR2 Carrel 2' => BigDecimal('0'),
      'LMAN Library Maintenance' => BigDecimal('0'),
      'ILL ILS: Loan' => BigDecimal('0'),
      'Access Patron' => BigDecimal('0')
    }
    bib_loans[mms_id][row['Patron Group']] += BigDecimal(row['Loans (Not In House)'])
  end
end

### Retrieve a report of all MMS IDs that had In House Loans in FY24 through FY25
bib_in_house = {}
CSV.open("#{input_dir}/usage_all_mms_ids_fy24-fy25.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    mms_id = row['MMS Id']
    next unless all_pul_ids.include?(mms_id)

    bib_in_house[mms_id] = BigDecimal(row['Loans (In House)'])
  end
end

### Connect SCSB barcodes to SCSB bib IDs
scsb_bib_to_barcodes = {}
File.open("#{input_dir}/cul_ebook_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    key = parts[2]
    next if match_to_ids[key].nil?

    bib_id = parts[0]
    barcode = parts[1]
    scsb_bib_to_barcodes[bib_id] ||= []
    scsb_bib_to_barcodes[bib_id] << barcode
  end
end

File.open("#{input_dir}/hl_ebook_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    key = parts[2]
    next if match_to_ids[key].nil?

    bib_id = parts[0]
    barcode = parts[1]
    scsb_bib_to_barcodes[bib_id] ||= []
    scsb_bib_to_barcodes[bib_id] << barcode
  end
end

File.open("#{input_dir}/nypl_ebook_match.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    key = parts[2]
    next if match_to_ids[key].nil?

    bib_id = parts[0]
    barcode = parts[1]
    scsb_bib_to_barcodes[bib_id] ||= []
    scsb_bib_to_barcodes[bib_id] << barcode
  end
end

### Load in SCSB usage per barcode
scsb_barcode_usage = {}
CSV.open("#{input_dir}/usage_all_resource_sharing_fy24-fy25_user_group.csv", 'r', headers: true,
                                                                                  encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    barcode = row['Barcode']
    scsb_barcode_usage[barcode] ||= {
      'P Faculty & Professional' => BigDecimal('0'),
      'GRAD Graduate Student' => BigDecimal('0'),
      'UGRD Undergraduate' => BigDecimal('0'),
      'SENR Senior Undergraduate' => BigDecimal('0'),
      'REG Regular Staff' => BigDecimal('0'),
      'GST Guest Patron' => BigDecimal('0'),
      'CAR1 Carrel 1' => BigDecimal('0'),
      'Affiliate' => BigDecimal('0'),
      'Affiliate-P Faculty Affiliate' => BigDecimal('0'),
      'CAR2 Carrel 2' => BigDecimal('0'),
      'LMAN Library Maintenance' => BigDecimal('0'),
      'ILL ILS: Loan' => BigDecimal('0'),
      'Access Patron' => BigDecimal('0')
    }
    scsb_barcode_usage[barcode][row['Patron Group']] += BigDecimal(row['Loans (Not In House)'])
  end
end

### Gather loans per user group by match key
match_to_ids.each_value do |info|
  pul_ids = info[:ebook]
  pul_ids += info[:pul_print] if info[:pul_print]
  pul_loans = {}
  partner_ids = []
  partner_ids += info[:cul] if info[:cul]
  partner_ids += info[:nypl] if info[:nypl]
  partner_ids += info[:hl] if info[:hl]
  in_house = BigDecimal('0')
  pul_ids.each do |id|
    in_house += bib_in_house[id] if bib_in_house[id]
    loan_info = bib_loans[id]
    next unless loan_info

    loan_info.each do |group, count|
      pul_loans[group] ||= BigDecimal('0')
      pul_loans[group] += count
    end
  end
  info[:pul_loans] = pul_loans
  info[:in_house] = in_house
  partner_loans = {}
  partner_ids.each do |bib_id|
    barcodes = scsb_bib_to_barcodes[bib_id]
    barcodes.each do |barcode|
      usage_info = scsb_barcode_usage[barcode]
      next unless usage_info

      usage_info.each do |group, count|
        partner_loans[group] ||= BigDecimal('0')
        partner_loans[group] += count
      end
    end
  end
  info[:partner_loans] = partner_loans
end

### Load COUNTER TR_B1 usage by ISBN report obtained from Analytics for FY24-FY25
isbn_usage = {}
CSV.open("#{input_dir}/ebooks_with_print_sushi_fy24-fy25.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    raw_isbn = row['Origin ISBN']
    normal_isbn = isbn_normalize(raw_isbn)
    isbn_usage[normal_isbn] ||= BigDecimal('0')
    isbn_usage[normal_isbn] += BigDecimal(row['Unique Requests'])
  end
end

### Link ISBNs to MMS IDs of electronic records
bib_to_isbn = {}
File.open("#{output_dir}/ebook_isbns.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    isbn = parts[1]
    bib_to_isbn[mms_id] ||= []
    bib_to_isbn[mms_id] << isbn
  end
end

### Group the bib info by match key
match_to_ids.each_value do |match_info|
  call_num = nil
  match_info[:electronic_collections] = []
  match_info[:print_locations] = []
  total_usage = BigDecimal('0')
  match_info[:pul_print]&.each do |id|
    info = bib_info[id]
    next unless info

    match_info[:electronic_collections] += info[:electronic_collections]
    match_info[:print_locations] += info[:print_locations]
    call_num = preferred_call_num(info[:lc_call_nums]) if call_num.nil?
  end
  match_info[:ebook].each do |id|
    isbns = bib_to_isbn[id]
    isbns&.each do |isbn|
      usage = isbn_usage[isbn]
      total_usage += usage if usage
    end
    info = bib_info[id]
    next unless info

    match_info[:electronic_collections] += info[:electronic_collections]
    match_info[:print_locations] += info[:print_locations]
    call_num = preferred_call_num(info[:lc_call_nums]) if call_num.nil?
  end
  match_info[:electronic] = total_usage
  match_info[:lc_call_num] = call_num
end

### Report out the records that have print matches
File.open("#{output_dir}/ebooks_with_print_matches.tsv", 'w') do |output|
  output.write("Match Key\tElectronic MMS IDs\tMatching Print Sites\t")
  output.write("PUL Print MMS IDs\tCUL IDs\tHL IDs\tNYPL IDs\t")
  output.write("LC Class\tLC Subclass\tLC Classification\tLC Call Number\tPUL Print Locations\t")
  output.write("Electronic Collections\tElectronic Usage\tBrowses\tHas Loans?\tHas SCSB Borrowing?\t")
  output.write("Faculty Usage\tFaculty Affiliate Usage\tStaff Usage\tGraduate Usage\tAffiliate Usage\t")
  output.write("Senior Usage\tUndergraduate Usage\tGuest Usage\tCAR1 Usage\tCAR2 Usage\t")
  output.puts("ILL Usage\tAccess Patron Usage\tLMAN Usage")
  match_to_ids.each do |key, info|
    keys_to_reject = %i[
      ebook print_locations electronic_collections electronic
      in_house pul_loans partner_loans lc_call_num
    ]
    site_blob = info.keys.reject { |symbol| keys_to_reject.include?(symbol) }
    all_usage = total_usage_per_group(info)
    output.write("#{key}\t")
    output.write("#{info[:ebook].join(' | ')}\t")
    output.write("#{site_blob.join(' | ')}\t")
    output.write("#{info[:pul_print].to_a.join(' | ')}\t")
    output.write("#{info[:cul].to_a.join(' | ')}\t")
    output.write("#{info[:hl].to_a.join(' | ')}\t")
    output.write("#{info[:nypl].to_a.join(' | ')}\t")
    if info[:lc_call_num]
      output.write("#{info[:lc_call_num].primary_lc_class}\t")
      output.write("#{info[:lc_call_num].sub_lc_class}\t")
      output.write("#{info[:lc_call_num].classification}\t")
      output.write("#{info[:lc_call_num].full_call_num}\t")
    else
      output.write("\t\t\t\t")
    end
    output.write("#{info[:print_locations].join(' | ')}\t")
    output.write("#{format_collections(info[:electronic_collections])}\t")
    output.write("#{info[:electronic].to_s('F')}\t")
    output.write("#{info[:in_house].to_s('F')}\t")
    if info[:pul_loans].any? { |_group, count| count > BigDecimal('0') }
      output.write("true\t")
    else
      output.write("false\t")
    end
    if info[:partner_loans].any? { |_group, count| count > BigDecimal('0') }
      output.write("true\t")
    else
      output.write("false\t")
    end
    if all_usage.empty?
      output.puts("0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0\t0")
    else
      output.write("#{all_usage['P Faculty & Professional'].to_s('F')}\t")
      output.write("#{all_usage['Affiliate-P Faculty Affiliate'].to_s('F')}\t")
      output.write("#{all_usage['REG Regular Staff'].to_s('F')}\t")
      output.write("#{all_usage['GRAD Graduate Student'].to_s('F')}\t")
      output.write("#{all_usage['Affiliate'].to_s('F')}\t")
      output.write("#{all_usage['SENR Senior Undergraduate'].to_s('F')}\t")
      output.write("#{all_usage['UGRD Undergraduate'].to_s('F')}\t")
      output.write("#{all_usage['GST Guest Patron'].to_s('F')}\t")
      output.write("#{all_usage['CAR1 Carrel 1'].to_s('F')}\t")
      output.write("#{all_usage['CAR2 Carrel 2'].to_s('F')}\t")
      output.write("#{all_usage['ILL ILS: Loan'].to_s('F')}\t")
      output.write("#{all_usage['Access Patron'].to_s('F')}\t")
      output.puts(all_usage['LMAN Library Maintenance'].to_s('F'))
    end
  end
end
