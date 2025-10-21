# frozen_string_literal: true

### Find monographic works where Princeton patrons have access to print and
###   electronic versions;
### For PUL items, creation date of the bib record is 7/1/23 or earlier
### For partner shared ReCAP items, accession date of the item is 7/1/23 or earlier

require_relative './../lib/lsp-data'
require 'csv'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Create a file of all barcodes accessioned into ReCAP 7/1/23 or earlier
File.open("#{output_dir}/recap_accessions_fy23_before.txt", 'w') do |output|
  output.puts('barcode')
  csv = CSV.open("#{input_dir}/LAS Tables/table250919.full.if.csv", 'r', headers: true, encoding: 'bom|utf-8')
  csv.each do |row|
    accession_date = DateTime.strptime(row['Accession Date'], '%m/%d/%y')
    next if accession_date > DateTime.strptime('07-01-2023', '%m-%d-%Y')

    output.puts(row['Item BarCode'])
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

### Report out the records that have print matches
File.open("#{output_dir}/ebooks_with_print_matches.tsv", 'w') do |output|
  output.puts("Match Key\tElectronic MMS IDs\tMatching Print Sites\tPUL Print MMS IDs\tCUL IDs\tHL IDs\tNYPL IDs")
  match_to_ids.each do |key, sites|
    next unless sites.size > 1

    output.write("#{key}\t")
    output.write("#{sites[:ebook].join(' | ')}\t")
    output.write("#{sites.keys.reject { |value| value == :ebook }.join(' | ')}\t")
    output.write("#{sites[:pul_print].join(' | ')}\t") if sites[:pul_print]
    output.write("#{sites[:cul].join(' | ')}\t") if sites[:cul]
    output.write("#{sites[:hl].join(' | ')}\t") if sites[:hl]
    output.puts(sites[:nypl].to_a.join(' | '))
  end
end
