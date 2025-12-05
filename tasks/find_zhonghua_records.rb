# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

def tracking_field(isbn)
  field = MARC::DataField.new('917', ' ', ' ')
  field.append(MARC::Subfield.new('a', isbn))
  field
end

### If the URL of the record matches the URL of the spreadsheet, trust that record

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
date = Time.new.strftime('%Y-%m-%d')
processed = []
writer = MARC::XMLWriter.new("#{output_dir}/all_zhonghua_records_with_isbns_#{date}.marcxml")
csv = CSV.open("#{input_dir}/zhonghua_list.csv", 'r', headers: true)
conn = nil
csv.each do |row|
  next if row['Existing MMS ID'][0] == '9'

  urls = []
  urls << row['URL'].gsub(%r{^https?://(.*)$}, '\1')
  urls << row['唯一标识符'] if row['唯一标识符'] =~ /^ZHB/
  matches = []
  tracking_id = nil
  urls.each do |url|
    next unless matches.empty?

    if (processed.size % 1_000).zero? || conn.nil?
      conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT,
                                 database_name: OCLC_Z3950_DATABASE_NAME,
                                 credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
    end
    match_class = OCLCRecordMatch.new(identifier: url, identifier_type: 'url', conn: conn)
    matches = match_class.records
    tracking_id = url
    processed << url
  end
  next unless matches.empty?

  isbn = row['标准编号']
  next unless isbn =~ /ISBN/

  normalized_isbn = isbn_normalize(isbn.gsub(/^ISBN (.*)$/, '\1'))
  match_class = OCLCRecordMatch.new(identifier: normalized_isbn, identifier_type: 'isbn', conn: conn)
  matches = match_class.records
  tracking_id = isbn
  processed << isbn
  matches.each do |record|
    record.append(tracking_field(tracking_id))
    writer.write(record)
  end
end
writer.close
