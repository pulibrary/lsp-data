# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

def tracking_field(isbn)
  field = MARC::DataField.new('917', ' ', ' ')
  field.append(MARC::Subfield.new('a', isbn))
  field
end

def invalid_record?(record)
  %w[3 u z].include?(record.leader[17]) ||
    record['040']['b'] != 'eng' ||
    record['245']['a'] !~ /[A-Za-z]/ ||
    record['880'].nil? ||
    record['948']['h'] =~ / 0 OTHER HOLDINGS/ ||
    record.fields('600'..'655').empty?
end

def filtered_matches(identifier:, identifier_type:, conn:)
  OCLCRecordMatch.new(identifier: identifier, identifier_type: identifier_type, conn: conn)
                 .records.reject { |record| invalid_record?(record) }
end

### If the URL of the record matches the URL of the spreadsheet, trust that record

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
date = Time.new.strftime('%Y-%m-%d')
processed = 0
writer = MARC::XMLWriter.new("#{output_dir}/zhonghua_records_filtered_#{date}.marcxml")
csv = CSV.open("#{input_dir}/zhonghua_list.csv", 'r', headers: true)
conn = nil
csv.each do |row|
  next if row['Existing MMS ID'][0] == '9'

  urls = [row['URL'].gsub(%r{^https?://(.*)$}, '\1')]
  urls << row['唯一标识符'] if row['唯一标识符'] =~ /^ZHB/
  matches = []
  tracking_id = nil
  urls.each do |url|
    next unless matches.empty?

    if (processed % 1_000).zero? || conn.nil?
      conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                                 credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
    end
    matches = filtered_matches(identifer: url, identifier_type: 'url', conn: conn)
    tracking_id = url
    processed += 1
  end
  next unless matches.empty?

  tracking_id = row['标准编号'] # Standard Number
  next unless tracking_id =~ /ISBN/

  normalized_isbn = isbn_normalize(tracking_id.gsub(/^ISBN (.*)$/, '\1'))
  matches = filtered_matches(identifier: normalized_isbn, identifier_type: 'isbn', conn: conn)
  processed += 1
  matches.each do |record|
    record.append(tracking_field(tracking_id))
    writer.write(record)
  end
end
writer.close
