# frozen_string_literal: true

### Find monographic works where Princeton patrons have access to print and
###   electronic versions;
### For PUL items, creation date of the bib record is 7/1/23 or earlier
### For partner shared ReCAP items, accession date of the item is 7/1/23 or earlier

require_relative './../lib/lsp-data'
require 'csv'
require 'bigdecimal'

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

      bc_matches = record.fields('876').select { |f| recap_accessions.include?(f['p']) }
      next if bc_matches.empty?

      key = MarcMatchKey::Key.new(record).key[0..-2]
      next unless electronic_match_keys.include?(key)

      bc_matches.each do |field|
        output.write("#{record['001'].value}\t")
        output.write("#{field['p']}\t")
        output.puts(key)
      end
    end
  end
end

File.open("#{output_dir}/hl_ebook_match.tsv", 'w') do |output|
  output.puts("Bib ID\tBarcode\tMatch Key")
  Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless record.leader[6..7] == 'am'

      bc_matches = record.fields('876').select { |f| recap_accessions.include?(f['p']) }
      next if bc_matches.empty?

      key = MarcMatchKey::Key.new(record).key[0..-2]
      next unless electronic_match_keys.include?(key)

      bc_matches.each do |field|
        output.write("#{record['001'].value}\t")
        output.write("#{field['p']}\t")
        output.puts(key)
      end
    end
  end
end

File.open("#{output_dir}/nypl_ebook_match.tsv", 'w') do |output|
  output.puts("Bib ID\tBarcode\tMatch Key")
  Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless record.leader[6..7] == 'am'

      bc_matches = record.fields('876').select { |f| recap_accessions.include?(f['p']) }
      next if bc_matches.empty?

      key = MarcMatchKey::Key.new(record).key[0..-2]
      next unless electronic_match_keys.include?(key)

      bc_matches.each do |field|
        output.write("#{record['001'].value}\t")
        output.write("#{field['p']}\t")
        output.puts(key)
      end
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

### Retrieve a report of all MMS IDs that had print usage in FY24 through FY25;
### For all IDs under a given key, total up the usage
bib_usage = {}
CSV.open("#{input_dir}/usage_all_mms_ids_fy24-fy25.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    bib_usage[row['MMS Id']] = {
      loans: BigDecimal(row['Loans (Not In House)']),
      in_house: BigDecimal(row['Loans (In House)'])
    }
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
CSV.open("#{input_dir}/usage_scsb_borrowing_fy24-fy25.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    barcode = row['Barcode']
    usage = row['Loans (Not In House) from Resource Sharing Borrowing Request']
    scsb_barcode_usage[barcode] ||= BigDecimal('0')
    scsb_barcode_usage[barcode] += BigDecimal(usage)
  end
end

key_usage = {}
match_to_ids.each do |key, sites|
  ids = sites[:ebook] + sites[:pul_print].to_a
  pul_usages = bib_usage.select { |id, _usage| ids.include?(id) }
  key_usage[key] ||= { loans: BigDecimal('0'), in_house: BigDecimal('0'), borrowing: BigDecimal('0') }
  pul_usages.each_value do |usage|
    key_usage[key][:loans] += usage[:loans]
    key_usage[key][:in_house] += usage[:in_house]
  end
  scsb_bibs = sites[:cul].to_a + sites[:hl].to_a + sites[:nypl].to_a
  scsb_bibs.each do |id|
    barcodes = scsb_bib_to_barcodes[id]
    barcodes.each do |barcode|
      usage = scsb_barcode_usage[barcode]
      key_usage[key][:borrowing] += usage if usage
    end
  end
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

### Add electronic usage to the key_usage hash
match_to_ids.each do |key, sites|
  ids = sites[:ebook]
  total_usage = BigDecimal('0')
  ids.each do |mms_id|
    isbns = bib_to_isbn[mms_id]
    next unless isbns

    isbns.each do |isbn|
      usage = isbn_usage[isbn]
      total_usage += usage if usage
    end
  end
  key_usage[key][:electronic] = total_usage
end

### Report out the records that have print matches
File.open("#{output_dir}/ebooks_with_print_matches.tsv", 'w') do |output|
  output.write("Match Key\tElectronic MMS IDs\tMatching Print Sites\t")
  output.puts("PUL Print MMS IDs\tCUL IDs\tHL IDs\tNYPL IDs\tLoans\tBrowses\tSCSB Borrowing\tElectronic Usage")
  match_to_ids.each do |key, sites|
    output.write("#{key}\t")
    output.write("#{sites[:ebook].join(' | ')}\t")
    output.write("#{sites.keys.reject { |value| value == :ebook }.join(' | ')}\t")
    output.write("#{sites[:pul_print].to_a.join(' | ')}\t")
    output.write("#{sites[:cul].to_a.join(' | ')}\t")
    output.write("#{sites[:hl].to_a.join(' | ')}\t")
    output.write("#{sites[:nypl].to_a.join(' | ')}\t")
    output.write("#{key_usage[key][:loans].to_s('F')}\t")
    output.write("#{key_usage[key][:in_house].to_s('F')}\t")
    output.write("#{key_usage[key][:borrowing].to_s('F')}\t")
    output.puts(key_usage[key][:electronic].to_s('F'))
  end
end
nil
