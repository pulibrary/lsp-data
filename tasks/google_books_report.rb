# frozen_string_literal: true

### Mark—would you be able to dump a file from Alma (or a cache somewhere)
###   for these items with their holdings?
###   I’d like to be able to do some analysis to look at, for example,
###   what locations these items are from, the approximate size, language,
###   country of origin, etc. I can do that analysis,
###   but I can’t get the full records with hammering the API.
require_relative './../lib/lsp-data'

def report_info(item, record)
  holding_id = item['0']
  holding852 = record.fields('852').find { |f| f['8'] == holding_id }
  holding866 = record.fields('866').select { |f| f['8'] == holding_id && f['a'] }
  f008 = record['008'] ? record['008'].value : ''
  {
    title: title(record),
    author: author(record),
    pub_info: publisher(record),
    pub_date_f008: f008[7..10],
    pub_place_f008: f008[15..17],
    language: f008[35..37],
    description: description(record),
    holding_id: holding_id,
    item_id: item['a'],
    barcode: item['p'],
    holding866: holding866.map { |f| f['a'] },
    call_number: call_number(holding852),
    library: holding852['b'],
    location: holding852['c'],
    retention_statements: holding_retention(record, holding_id),
    enum: item['3']
  }
end

def matched_items(record, candidates)
  all_items = record.fields('876').select { |field| field['a'] =~ /^23[0-9]+6421$/ }
  candidate_barcodes = candidates.map { |candidate| candidate[:barcode] }
  all_items.select { |field| candidate_barcodes.include?(field['p']) }
end

def call_number(f852)
  [f852['k'], f852['h'], f852['i']].join(' ').strip
end

def holding_retention(record, holding_id)
  fields = record.fields('583').select { |f| f['8'] == holding_id }
  statements = []
  fields.each do |field|
    statements << field.subfields.reject { |s| s.code == '8' }
                       .map(&:value)
                       .join(' ')
  end
  statements
end

def auth_subfields_to_skip(field_tag)
  case field_tag
  when '100', '110'
    %w[0 1 6 e]
  else
    %w[0 1 6 j]
  end
end

def author(record)
  auth_fields = record.fields(%w[100 110 111])
  return if auth_fields.empty?

  auth_field = auth_fields.first
  auth_tag = auth_field.tag
  subf_to_skip = auth_subfields_to_skip(auth_tag)
  targets = auth_field.subfields.reject do |subfield|
    subf_to_skip.include?(subfield.code)
  end
  author = targets.map(&:value).join(' ')
  scrub_string(author)
end

def title(record)
  f245 = record['245']
  return unless f245

  title_string = ''
  title_string = title_string.dup
  if f245['a']
    title_string = f245['a']
  else
    targets = f245.subfields.reject { |subfield| subfield.code == '6' }
    c_index = targets.index { |subfield| subfield.code == 'c' }
    c_index ||= -1
    subf_values = targets[0..c_index].map(&:value)
    title_string = subf_values.join(' ')
  end
  scrub_string(title_string)
end

def description(record)
  f300 = record['300']
  return unless f300

  text = f300.subfields.map(&:value).join(' ')
  scrub_string(text)
end

def publisher(record)
  f260 = record['260']
  f264 = record.fields('264')
  return publisher_info(f260) if f260

  unless f264.empty?
    target_field = select_f264(f264)
    return publisher_info(target_field)
  end
  { pub_place: nil, pub_name: nil, pub_date: nil }
end

def publisher_info(field)
  pub_place = scrub_string(field['a'])
  pub_name = scrub_string(field['b'])
  pub_date = scrub_string(field['c'])
  { pub_place: pub_place, pub_name: pub_name, pub_date: pub_date }
end

def select_f264(f264)
  f264.min_by(&:indicator2)
end

def scrub_string(string)
  return if string.nil?

  new_string = string.dup
  new_string.strip!
  new_string[-1] = '' if new_string[-1] =~ %r{[.,:/=]}
  new_string.strip!
  new_string.gsub(/(\s){2, }/, '\1')
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

google_candidates = {}
File.open("#{input_dir}/prnc-2025-05-15_combined.txt", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    bib_id = parts[0]
    mms_id = bib_id =~ /^99[0-9]+6421$/ ? bib_id : "99#{bib_id}3506421"
    barcode = parts[8]
    enum = parts[7]
    google_candidates[mms_id] ||= []
    google_candidates[mms_id] << { barcode: barcode, enum: enum }
  end
end

### First, find the bib records that match the MMS IDs;
###   item filtering will happen afterwards
google_mms_ids = Set.new(google_candidates.keys)

google_records = {} # MMS ID is the key, record is the value
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    mms_id = record['001'].value
    google_records[mms_id] = record if google_mms_ids.include?(mms_id)
  end
end

File.open("#{output_dir}/missing_ids_google_candidates.txt", 'w') do |output|
  output.puts('MMS ID')
  missing_ids = google_mms_ids - Set.new(google_records.keys)
  missing_ids.each { |id| output.puts(id) }
end

### Output the records for others to do their own MARC analysis
writer = MARC::XMLWriter.new("#{output_dir}/google_books_candidates_marc_file.marcxml")
google_records.each_value { |record| writer.write(record) }
writer.close

### Produce a report for staff to review
###   1. If there is a match on barcode, use that item
###   2. If there are any items the barcode does not match the candidate list,
###     and the number of items on the bib is equal to the number
###     of candidate items, assume the remaining items are the targets
File.open("#{output_dir}/google_books_candidates_report.tsv", 'w') do |output|
  output.write("MMS ID\tTitle\tAuthor\tPublisher Place\tPublisher Name\t")
  output.write("Publisher Date\t008 Publisher Place\t008 Date1\t")
  output.write("Physical Description\t008 Language\tHolding ID\tLibrary Code\t")
  output.puts("Location Code\tCall Number\t866 Fields\tItem ID\tBarcode\tItem Enum\tRetention Commitments")
  google_records.each do |mms_id, record|
    candidates = google_candidates[mms_id]
    matched_items = matched_items(record, candidates)
    all_items = record.fields('876').select { |field| field['a'] =~ /^23[0-9]+6421$/ }
    unmatched_items = all_items - matched_items
    matched_items.each do |item|
      info = report_info(item, record)
      output.write("#{mms_id}\t")
      output.write("#{info[:title]}\t")
      output.write("#{info[:author]}\t")
      output.write("#{info[:pub_info][:pub_place]}\t")
      output.write("#{info[:pub_info][:pub_name]}\t")
      output.write("#{info[:pub_info][:pub_date]}\t")
      output.write("#{info[:pub_place_f008]}\t")
      output.write("#{info[:pub_date_f008]}\t")
      output.write("#{info[:description]}\t")
      output.write("#{info[:language]}\t")
      output.write("#{info[:holding_id]}\t")
      output.write("#{info[:library]}\t")
      output.write("#{info[:location]}\t")
      output.write("#{info[:call_number]}\t")
      output.write("#{info[:holding866].join(' | ')}\t")
      output.write("#{info[:item_id]}\t")
      output.write("#{info[:barcode]}\t")
      output.write("#{info[:enum]}\t")
      output.puts(info[:retention_statements].join(' | '))
    end
    next unless candidates.size == all_items.size

    unmatched_items.each do |item|
      info = report_info(item, record)
      output.write("#{mms_id}\t")
      output.write("#{info[:title]}\t")
      output.write("#{info[:author]}\t")
      output.write("#{info[:pub_info][:pub_place]}\t")
      output.write("#{info[:pub_info][:pub_name]}\t")
      output.write("#{info[:pub_info][:pub_date]}\t")
      output.write("#{info[:pub_place_f008]}\t")
      output.write("#{info[:pub_date_f008]}\t")
      output.write("#{info[:description]}\t")
      output.write("#{info[:language]}\t")
      output.write("#{info[:holding_id]}\t")
      output.write("#{info[:library]}\t")
      output.write("#{info[:location]}\t")
      output.write("#{info[:call_number]}\t")
      output.write("#{info[:holding866].join(' | ')}\t")
      output.write("#{info[:item_id]}\t")
      output.write("#{info[:barcode]}\t")
      output.write("#{info[:enum]}\t")
      output.puts(info[:retention_statements].join(' | '))
    end
  end
end
