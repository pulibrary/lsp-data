# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

def inventory_info(record)
  item_fields = record.fields('876').select { |field| field['0'] =~ /^23[0-9]+6421$/ }
  item_fields.map do |field|
    {
      inventory_num: field['i'], library: field['y'],
      location: field['z'], barcode: field['p']
    }
  end
end

def tracking_field
  field = MARC::DataField.new('917', ' ', ' ')
  field.append(MARC::Subfield.new('a', 'backlog_enhanced'))
  field.append(MARC::Subfield.new('b', Time.new.strftime('%Y-%m-%d')))
  field
end

def clean_match(record:, mms_id:)
  record.fields.delete_if { |field| %w[001 003].include?(field.tag) || field.tag[0] == '9' }
  record.append(MARC::ControlField.new('001', mms_id))
  record.append(tracking_field)
  record
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
date = Time.new.strftime('%Y-%m-%d')
processed = []
writer = MARC::XMLWriter.new("#{output_dir}/backlog_enhancement_#{date}.marcxml")
report = File.open("#{output_dir}/backlog_enhancement_#{date}_report.tsv", 'w')
header_row = [
  'MMS ID', 'Inventory Number', 'Language Code',
  'Library Code', 'Location Code', 'Title', 'ISBNs', 'Matched OCLC Number'
]
report.puts(header_row.join("\t"))
fname = 'backlog_44877285080006421_20251114_141146[034].xml_new'
reader = MARC::XMLReader.new("#{input_dir}/#{fname}", parser: 'magic', ignore_namespace: true)
conn = nil
reader.each do |record|
  mms_id = record['001'].value
  next if processed.include?(mms_id)

  if (processed.size % 1_000).zero? || conn.nil?
    conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT,
                               database_name: OCLC_Z3950_DATABASE_NAME,
                               credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end
  title = record['245']['a']
  match = nil
  all_isbns = isbns(record)
  all_isbns.each do |isbn|
    break if match

    match_class = OCLCRecordMatch.new(identifier: isbn, identifier_type: 'isbn', conn: conn)
    match = match_class.filtered_records(title).first
  end
  if match
    language_code = match['008'].value[35..37]
    cleaned_record = clean_match(record: match, mms_id: mms_id)
    writer.write(cleaned_record)
    inventory_info(record).each do |item|
      report.write("#{mms_id}\t#{item[:inventory_num]}\t#{language_code}\t#{item[:library]}\t")
      report.puts("#{item[:location]}\t#{title}\t#{all_isbns.join(' | ')}\t#{oclcs(record: cleaned_record).first}")
    end
  end
  processed << mms_id
end
writer.close
report.close
