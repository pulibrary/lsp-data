# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'csv'

def tracking_field(isbn)
  field = MARC::DataField.new('917', ' ', ' ')
  field.append(MARC::Subfield.new('a', isbn))
  field
end

def insufficient_subjects?(record)
  record['050'].nil? || record.fields('600'..'655').empty?
end

def invalid_record?(record)
  %w[3 u z].include?(record.leader[17]) ||
    record['040']['b'] != 'eng' ||
    record['245']['a'] !~ /[A-Za-z]/ ||
    record['880'].nil? ||
    record['948']['h'] =~ / 0 OTHER HOLDINGS/ ||
    insufficient_subjects?(record)
end

def title_type(row)
  if row['其他题名信息']
    'collection'
  else
    'single'
  end
end

def match_title(title_type:, row:)
  if title_type == 'single'
    row['题名']
  else
    row['其他题名信息'].gsub(/^\*(.*)$/, '\1')
  end
end

def matched_title?(row:, record:)
  title_to_match = match_title(title_type: title_type(row), row: row)
  f880 = record.fields('880').find { |field| field['6'][0..2] == '245' }
  f880.nil? || /^#{title_to_match}/.match?(f880['a'])
end

def series_requirement?(row:, record:)
  if row['丛编']
    record.fields('490').size.positive?
  else
    true
  end
end

def filtered_matches(identifier:, identifier_type:, conn:, row:)
  OCLCRecordMatch.new(identifier: identifier, identifier_type: identifier_type, conn: conn)
                 .records.map { |record| convert_rec_to_trad(chi_simp_rec: record) }
                 .reject do |record|
                   invalid_record?(record) &&
                     !matched_title?(row: row, record: record) &&
                     !series_requirement?(row: row, record: record)
                 end
end

# Converts an entire MARC record object from Simplified to Traditional characters
def convert_rec_to_trad(chi_simp_rec:)
  chi_simp_mrc = ChineseConversion.new(chi_simp_rec.to_marc)
  MARC::Record.new_from_marc(chi_simp_mrc.converted)
end

def add_isbn_matches(conn:, row:)
  hash = {}
  hash[:tracking_id] = row['标准编号'] # Standard Number
  hash[:matches] = []
  return hash unless hash[:tracking_id] =~ /ISBN/

  normalized_isbn = isbn_normalize(hash[:tracking_id].gsub(/^ISBN (.*)$/, '\1'))
  return hash if normalized_isbn.nil?

  hash[:matches] += filtered_matches(identifier: normalized_isbn, identifier_type: 'isbn', conn: conn, row: row)
  hash
end

### If the URL of the record matches the URL of the spreadsheet, trust that record

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)
date = Time.new.strftime('%Y-%m-%d')
processed = 0
single_writer = MARC::XMLWriter.new("#{output_dir}/zhonghua_records_filtered_one_per_match_#{date}.marcxml")
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
    matches = filtered_matches(identifier: url, identifier_type: 'url', conn: conn, row: row)
    tracking_id = url
    processed += 1
  end
  if matches.empty?
    isbn_matches = add_isbn_matches(conn: conn, row: row)
    matches += isbn_matches[:matches]
    tracking_id = isbn_matches[:tracking_id]
  end
  processed += 1
  matches.each_with_index do |record, index|
    record.append(tracking_field(tracking_id))
    writer.write(record)
    single_writer.write(record) if index.zero?
  end
end
writer.close
single_writer.close
