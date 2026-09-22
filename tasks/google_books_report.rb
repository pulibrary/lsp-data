# frozen_string_literal: true

### Mark—would you be able to dump a file from Alma (or a cache somewhere)
###   for these items with their holdings?
###   I’d like to be able to do some analysis to look at, for example,
###   what locations these items are from, the approximate size, language,
###   country of origin, etc. I can do that analysis,
###   but I can’t get the full records with hammering the API.
require_relative '../lib/lsp-data'

def call_number(f852)
  [f852['k'], f852['h'], f852['i']].join(' ').strip
end

def holding_retention(record, holding_id)
  fields = record.fields('583').select { |f| f['8'] == holding_id }
  fields.map do |field|
    field.subfields.reject { |s| s.code == '8' }
         .map(&:value)
         .join(' ')
  end
end

def holding866(record, holding_id)
  fields = record.fields('866').select { |f| f['8'] == holding_id && f['a'] }.map { |f| f['a'] }
  { holding866: fields }
end

def holding852_hash(record, holding_id)
  holding852 = record.fields('852').find { |f| f['8'] == holding_id }
  {
    holding_id: holding_id,
    library: holding852['b'],
    location: holding852['c'],
    call_number: call_number(holding852),
    retention_statements: holding_retention(record, holding_id)
  }
end

def item_hash(item)
  { item_id: item['a'], barcode: item['p'], enum: item['3'] }
end

def report_info_holdings(item, record)
  holding_id = item['0']
  holding852 = holding852_hash(record, holding_id)
  holding852.merge(holding866(record, holding_id), item_hash(item))
end

def f008_hash(record)
  f008 = record['008'] ? record['008'].value : ''
  {
    pub_date_f008: f008[7..10],
    pub_place_f008: f008[15..17],
    language: f008[35..37]
  }
end

def report_info_bib(record)
  hash = {
    mms_id: record['001'].value,
    title: title(record),
    author: author(record)&.gsub(/\s/, ' '),
    pub_info: publisher(record),
    description: description(record)
  }
  hash.merge(f008_hash(record))
end

def report_info(item, record)
  holding_hash = report_info_holdings(item, record)
  holding_hash.merge(report_info_bib(record))
end

def matched_items(record, candidates)
  all_items = record.fields('876').select { |field| field['a'] =~ /^23[0-9]+6421$/ }
  candidate_barcodes = candidates.map { |candidate| candidate[:barcode] }
  all_items.select { |field| candidate_barcodes.include?(field['p']) }
end

def write_bib_info_to_report(output, info)
  output.write("#{info[:mms_id]}\t#{info[:title]}\t#{info[:author]}\t")
  output.write("#{info[:pub_info][:pub_place]}\t#{info[:pub_info][:pub_name]}\t#{info[:pub_info][:pub_date]}\t")
  output.write("#{info[:pub_place_f008]}\t#{info[:pub_date_f008]}\t")
  output.write("#{info[:description]}\t#{info[:language]}\t")
end

def write_holding_info_to_report(output, info)
  output.write("#{info[:holding_id]}\t#{info[:library]}\t#{info[:location]}\t#{info[:call_number]}\t")
  output.write("#{info[:holding866].join(' | ')}\t")
  output.write("#{info[:item_id]}\t#{info[:barcode]}\t#{info[:enum]}\t")
  output.puts(info[:retention_statements].join(' | '))
end

def write_line_to_report(output, info)
  write_bib_info_to_report(output, info)
  write_holding_info_to_report(output, info)
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

google_candidates = {}
Dir.glob("#{input_dir}/candidates/*.txt").each do |file|
  File.open(file, 'r') do |input|
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      bib_id = parts[0]
      mms_id = bib_id =~ /^99[0-9]+6421$/ ? bib_id : "99#{bib_id}3506421"
      barcode = parts[8].gsub(/\s/, '')
      enum = parts[7]
      google_candidates[mms_id] ||= []
      google_candidates[mms_id] << { barcode: barcode, enum: enum }
    end
  end
end

### First, find the bib records that match the MMS IDs;
###   item filtering will happen afterwards
barcodes_found = Set.new
date = Time.new.strftime('%Y-%m-%d')
report = File.open("#{output_dir}/google_books_candidates_report_nonrecap_#{date}.tsv", 'w')
recap = File.open("#{output_dir}/google_books_candidates_report_recap_#{date}.tsv", 'w')
extra_items = File.open("#{output_dir}/google_books_candidates_report_other_items_#{date}.tsv", 'w')
fake_items = File.open("#{output_dir}/google_books_candidates_report_fake_items_#{date}.tsv", 'w')
writer = MARC::XMLWriter.new("#{output_dir}/google_books_candidates_marc_file_#{date}.marcxml")
header_row = [
  'MMS ID', 'Title', 'Author',
  'Publisher Place', 'Publisher Name', 'Publisher Date',
  '008 Publisher Place', '008 Date1', 'Physical Description', '008 Language',
  'Holding ID', 'Library Code', 'Location Code', 'Call Number', '866 Fields',
  'Item ID', 'Barcode', 'Item Enum', 'Retention Commitments'
].join("\t")
report.puts(header_row)
recap.puts(header_row)
extra_items.puts(header_row)
fake_items.puts(header_row)
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    mms_id = record['001'].value
    candidates = google_candidates[mms_id]
    next unless candidates

    writer.write(record)
    matched_items = matched_items(record, candidates)
    all_items = record.fields('876').select { |field| field['a'] =~ /^23[0-9]+6421$/ }
    unmatched_items = all_items - matched_items
    matched_items.each do |item|
      info = report_info(item, record)
      item['y'] == 'recap' ? write_line_to_report(recap, info) : write_line_to_report(report, info)
      barcodes_found << item['p']
    end
    unmatched_items.each do |item|
      info = report_info(item, record)
      item['p'] =~ /^32101/ ? write_line_to_report(extra_items, info) : write_line_to_report(fake_items, info)
    end
  end
end
report.close
recap.close
extra_items.close
fake_items.close
writer.close

File.open("#{output_dir}/missing_barcodes_google_candidates_#{date}.tsv", 'w') do |output|
  output.write("Bib ID\tYear of Publication\tAuthor\tTitle\tRemainder of Title\t")
  output.puts("LC Class\tCutter\tEnumeration\tBarcode")
  Dir.glob("#{input_dir}/candidates/*.txt").each do |file|
    File.open(file, 'r') do |input|
      while (line = input.gets)
        line.chomp!
        parts = line.split("\t")
        bib_id = parts[0]
        mms_id = bib_id =~ /^99[0-9]+6421$/ ? bib_id : "99#{bib_id}3506421"
        barcode = parts[8].gsub(/\s/, '')
        next if barcodes_found.include?(barcode)

        output.write("#{mms_id}\t#{parts[1]}\t#{parts[2]}\t#{parts[3]}\t#{parts[4]}\t")
        output.puts("#{parts[5]}\t#{parts[6]}\t#{parts[7]}\t#{barcode}")
      end
    end
  end
end
