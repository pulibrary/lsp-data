# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'csv'
input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

def identifiers_from_row(row)
  isbns = row['isbns'].to_s.split(', ').map { |isbn| isbn_normalize(isbn) || isbn }
  {
    isbns: isbns.uniq.compact,
    lccns: row['lccns'].to_s.split(', '),
    oclcs: row['oclcs'].to_s.split(', ')
  }
end

def process_oclc_record(title_id:, record:, num_hash:, record_hash:)
  oclc_num = oclcs(record: record).first
  num_hash[title_id] ||= []
  record_hash[title_id] ||= []
  return if num_hash[title_id].include?(oclc_num)

  record.append(MARC::DataField.new('999', ' ', ' ', ['a', MarcMatchKey::Key.new(record).key[0..-2]]))
  num_hash[title_id] << oclc_num
  record_hash[title_id] << record
end

### 1. Retrieve all records by ISBN and OCLC number identifiers from OCLC via Z39.50
###   [LCCN is likely not going to deliver any more records,
###   and I don't currently have functionality to retrieve by LCCN]
### 2. Link the retrieved records to the title_id from the original database
###   and generate GoldRush keys for each title
title_id_to_oclc_nums = {}
records_by_title_id = {}

conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                           credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
CSV.open("#{input_dir}/Space Opera V2.csv", 'r', headers: true, encoding: 'bom|utf-8').each do |row|
  identifiers = identifiers_from_row(row)
  title_id = row['title_id'].to_i
  identifiers[:oclcs].each do |oclc|
    records = OCLCRecordMatch.new(identifier: oclc, identifier_type: 'oclc', conn: conn).records
    records.each do |record|
      process_oclc_record(title_id: title_id, record: record,
                          num_hash: title_id_to_oclc_nums, record_hash: records_by_title_id)
    end
  end
  identifiers[:isbns].each do |isbn|
    records = OCLCRecordMatch.new(identifier: isbn, identifier_type: 'isbn', conn: conn).records
    records.each do |record|
      process_oclc_record(title_id: title_id, record: record,
                          num_hash: title_id_to_oclc_nums, record_hash: records_by_title_id)
    end
  end
  identifiers[:lccns].each do |lccn|
    records = OCLCRecordMatch.new(identifier: lccn, identifier_type: 'lccn', conn: conn).records
    records.each do |record|
      process_oclc_record(title_id: title_id, record: record,
                          num_hash: title_id_to_oclc_nums, record_hash: records_by_title_id)
    end
  end
end
### 3. Retrieve OCLC holdings for each OCLC record retrieved
client_id = ENV.fetch('SEARCH_API_ID', nil)
client_secret = ENV.fetch('SEARCH_API_SECRET', nil)
scope = 'wcapi'

oauth = OAuth.new(client_id: client_id,
                  client_secret: client_secret,
                  url: OCLC_OAUTH_ENDPOINT,
                  scope: scope)
oauth_response = oauth.response
conn = api_conn(SEARCH_API_ENDPOINT)
holdings_by_oclc_num = {}
title_id_to_oclc_nums.each_value do |oclc_nums|
  oclc_nums.each do |oclc_num|
    next if holdings_by_oclc_num[oclc_num]

    puts oclc_num
    holdings_by_oclc_num[oclc_num] = OCLCHoldings.new(identifier: { type: 'oclcNumber', value: oclc_num },
                                                      conn: conn, token: oauth_response[:token]).holdings
  end
end
### 4. Use the GoldRush match key to match on all titles in Alma [omit the last character]
goldrush_to_oclc = {}
records_by_title_id.each_value do |records|
  records.each do |record|
    oclc_num = oclcs(record: record).first
    goldrush_to_oclc[record['999']['a']] ||= []
    goldrush_to_oclc[record['999']['a']] << oclc_num
  end
end
all_goldrush_keys = Set.new(goldrush_to_oclc.keys)

goldrush_to_alma = {} # goldrush key to inventory type to MMS IDs
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next if record.leader[5] == 'd'

    key = MarcMatchKey::Key.new(record).key[0..-2]
    next unless all_goldrush_keys.include?(key)

    physical = record.fields('852').any? { |field| field['8'] =~ /^22[0-9]+6421$/ }
    electronic = record.fields('951').any? { |field| field['0'] =~ /6421$/ && field['a'] == 'Available' }
    next unless physical || electronic

    goldrush_to_alma[key] ||= { physical: [], electronic: [] }
    goldrush_to_alma[key][:physical] << record['001'].value if physical
    goldrush_to_alma[key][:electronic] << record['001'].value if electronic
  end
end
### 5. Report out the total number of holdings in OCLC, the electronic MMS IDs, and the print MMS IDs
output = File.open("#{output_dir}/space_opera_holdings.tsv", 'w')
output.write("title_id\ttitle\tauthor\tyear\tisbns\tlccns\toclcs\thtid\t")
output.puts("total_oclc_holdings\trecap_partner_holdings\tAny PUL?\tprint MMS IDs\telectronic MMS IDs")
CSV.open("#{input_dir}/Space Opera V2.csv", 'r', headers: true, encoding: 'bom|utf-8').each do |row|
  title_id = row['title_id'].to_i
  oclc_nums = title_id_to_oclc_nums[title_id]
  goldrush_keys = goldrush_to_oclc.select { |_key, nums| oclc_nums.intersect?(nums) }.keys
  oclc_holdings = holdings_by_oclc_num.slice(*oclc_nums)
  total_holdings = oclc_holdings.values.map { |info| info[:total_holdings_count].to_i }&.sum
  all_oclc_symbols = oclc_holdings.values.map { |info| info[:holdings] }.flatten.uniq
  recap_partners = %w[ZCU HUL NYP PUL] & all_oclc_symbols
  alma_ids = goldrush_to_alma.slice(*goldrush_keys).values
  electronic_ids = alma_ids.map { |ids| ids[:electronic] }.flatten.uniq
  print_ids = alma_ids.map { |ids| ids[:physical] }.flatten.uniq
  output.write("#{title_id}\t#{row['title']}\t#{row['author']}\t#{row['year']}\t#{row['isbns']}\t")
  output.write("#{row['lccns']}\t#{row['oclcs']}\t#{row['htid']}\t")
  output.write("#{total_holdings}\t#{recap_partners.join(' | ')}\t")
  output.puts("#{(electronic_ids + print_ids).size.positive?}\t#{print_ids.join(' |')}\t#{electronic_ids.join(' | ')}")
end
output.close
