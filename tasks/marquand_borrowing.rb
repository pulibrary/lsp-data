# frozen_string_literal: true

### 1. Records are retrieved from OCLC for ILLiad borrowing standard numbers
### 2. An overlap analysis using GoldRush is performed against the ILLiad records,
###   SCSB shared records, and bibs from Alma with Marquand items
### 3. Final report includes [one line per Marquand item]:
###   a. Identifiers of Marquand items (MMS, Holding, item, Barcode)
###   b. Title of Marquand item
###   c. Location of Marquand item
###   d. Number of ILLiad requests
###   e. Number of BorrowDirect requests [if possible to separate from general ILLiad requests]
###   f. Number of SCSB requests
require_relative '../lib/lsp-data'
require 'csv'

def request_count_from_partners(scsb_partners:, requests_per_barcode:)
  total_requests = 0
  scsb_partners.each_value do |bib_hash|
    bib_hash.values.flatten.each do |item|
      requests = requests_per_barcode[item[:barcode]].to_a
      total_requests += requests.size
    end
  end
  total_requests
end

def info_from_scsb_partners(scsb_partners)
  {
    owning_institutions: scsb_partners.keys.map(&:to_s).map(&:upcase),
    cgds: Set.new(scsb_partners.values.map(&:values).flatten.map { |item| item[:cgd] }),
    customer_codes: Set.new(scsb_partners.values.map(&:values).flatten.map { |item| item[:customer_code] })
  }
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### 1. Records are retrieved from OCLC for ILLiad borrowing standard numbers
all_borrowing = ILLiad.new.all_borrowing.select { |transaction| transaction.transaction_status == 'Request Finished' }

# Make hashes linking each standard number to transaction IDs
isbn_to_transaction_id = {}
issn_to_transaction_id = {}
oclc_to_transaction_id = {}
all_borrowing.each do |transaction|
  if transaction.isbn
    isbn_to_transaction_id[transaction.isbn] ||= []
    isbn_to_transaction_id[transaction.isbn] << transaction.transaction_number
  end
  if transaction.issn
    issn_to_transaction_id[transaction.issn] ||= []
    issn_to_transaction_id[transaction.issn] << transaction.transaction_number
  end
  if transaction.oclc_num =~ /^[0-9]+$/
    oclc_to_transaction_id[transaction.oclc_num.strip] ||= []
    oclc_to_transaction_id[transaction.oclc_num.strip] << transaction.transaction_number
  end
end

### Retrieve records from OCLC via Z39.50 on identifiers, and link the resulting GoldRush keys to transactions
### It takes 12 hours to do this, so the results are written to disk to avoid loss
conn = nil
processed = 0
goldrush_output = File.open("#{output_dir}/marquand_oclc_goldrush_to_transaction.tsv", 'w')
oclc_to_transaction_id.each do |oclc_num, transaction_ids|
  if (processed % 1_000).zero? || conn.nil?
    conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                               credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end
  records = OCLCRecordMatch.new(identifier: oclc_num, identifier_type: 'oclc', conn: conn).records
  processed += 1
  records.each do |record|
    goldrush_key = MarcMatchKey::Key.new(record).key
    transaction_ids.each { |id| goldrush_output.puts("#{goldrush_key}\t#{id}") }
  end
end
conn = nil
processed = 0
isbn_to_transaction_id.each do |isbn, transaction_ids|
  if (processed % 1_000).zero? || conn.nil?
    conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                               credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end
  records = OCLCRecordMatch.new(identifier: isbn, identifier_type: 'isbn', conn: conn).records
  processed += 1
  records.each do |record|
    goldrush_key = MarcMatchKey::Key.new(record).key
    transaction_ids.each { |id| goldrush_output.puts("#{goldrush_key}\t#{id}") }
  end
end
conn = nil
processed = 0
issn_to_transaction_id.each do |issn, transaction_ids|
  if (processed % 1_000).zero? || conn.nil?
    conn = Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                               credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end
  records = OCLCRecordMatch.new(identifier: issn, identifier_type: 'issn', conn: conn).records
  processed += 1
  records.each do |record|
    goldrush_key = MarcMatchKey::Key.new(record).key
    transaction_ids.each { |id| goldrush_output.puts("#{goldrush_key}\t#{id}") }
  end
end
goldrush_output.close
goldrush_to_transaction_id = {}
File.open("#{output_dir}/marquand_oclc_goldrush_to_transaction.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    goldrush_to_transaction_id[parts[0]] ||= []
    goldrush_to_transaction_id[parts[0]] << parts[1].to_i
  end
end
### Find unsuppressed records in Alma with at least one holding in the marquand owning library;
### Link GoldRush key to MMS IDs;
### Also retain the following pieces of information about the bib:
###   1. MMS ID
###   2. Title
###   3. Author
###   4. Holdings
###     a. Call Number
###     b. Library$Location
###     c. Holding ID
###   5. Publisher
###   6. Publication year from 008
###   7. ISBNs
###   8. ISSNs
###   9. OCLC Numbers
goldrush_to_mms_id = {}
bib_info = {} ### MMS ID is key
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd'

    holdings = record.fields('852').select { |f| f['8'] =~ /^22[0-9]+6421$/ && f['b'] == 'marquand' }
    next if holdings.empty?

    mms_id = record['001'].value
    goldrush_key = MarcMatchKey::Key.new(record).key
    goldrush_to_mms_id[goldrush_key] ||= []
    goldrush_to_mms_id[goldrush_key] << mms_id
    pub_year = record['008']&.value
    bib_info[mms_id] = {
      title: title(record), author: author(record), publisher: publisher(record),
      pub_year: pub_year, standard_nums: standard_nums(record: record), holdings: []
    }
    holdings.each do |holding|
      call_num = ParsedCallNumber.new(primary_subfield: holding.subfields.find { |subfield| subfield.code == 'h' },
                                      item_subfields: holding.subfields.select { |subfield| subfield.code == 'i' },
                                      assume_lc: holding.indicator2 == '1')
      bib_info[mms_id][:holdings] << {
        id: holding['8'], call_num: call_num,
        location: "#{holding['b']}$#{holding['c']}"
      }
    end
  end
end

### Look through the partner full dumps of shared material to find records
###   that match the above GoldRush keys
### Data to retain:
###   1. SCSB ID
###   2. Barcodes
###   3. Owning Institution
###   4. Customer Codes
###   5. CGDs
goldrush_to_partners = {}
Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic').each do |record|
    key = MarcMatchKey::Key.new(record).key
    next unless goldrush_to_mms_id[key]

    id = record['001'].value
    goldrush_to_partners[key] ||= {}
    goldrush_to_partners[key][:cul] ||= {}
    goldrush_to_partners[key][:cul][id] = []
    record.fields('876').each do |field|
      hash = { barcode: field['p'], customer_code: field['z'], cgd: field['x'] }
      goldrush_to_partners[key][:cul][id] << hash
    end
  end
end
Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic').each do |record|
    key = MarcMatchKey::Key.new(record).key
    next unless goldrush_to_mms_id[key]

    id = record['001'].value
    goldrush_to_partners[key] ||= {}
    goldrush_to_partners[key][:hl] ||= {}
    goldrush_to_partners[key][:hl][id] = []
    record.fields('876').each do |field|
      hash = { barcode: field['p'], customer_code: field['z'], cgd: field['x'] }
      goldrush_to_partners[key][:hl][id] << hash
    end
  end
end
Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic').each do |record|
    key = MarcMatchKey::Key.new(record).key
    next unless goldrush_to_mms_id[key]

    id = record['001'].value
    goldrush_to_partners[key] ||= {}
    goldrush_to_partners[key][:nypl] ||= {}
    goldrush_to_partners[key][:nypl][id] = []
    record.fields('876').each do |field|
      hash = { barcode: field['p'], customer_code: field['z'], cgd: field['x'] }
      goldrush_to_partners[key][:nypl][id] << hash
    end
  end
end

### Export all requests from SCSB and gather stats about borrowing activity
###   for the barcodes identified above
### Data to retain:
###   1. Barcode
###   2. Delivery Location
###   3. Request Date [Time object]
requests_per_barcode = {}
CSV.open("#{input_dir}/all_pul_scsb_transactions.csv", 'r', headers: true, encoding: 'bom|utf-8').each do |row|
  barcode = row['Item Barcode']
  requests_per_barcode[barcode] ||= []
  requests_per_barcode[barcode] << {
    delivery_location: row['Delivery Location'],
    request_date: Time.parse(row['Request Date'])
  }
end

### 3. Final report includes [one line per Marquand item]:
###   a. Identifiers of Marquand holding (MMS, Holding)
###   b. Title of Marquand item
###   c. Location of Marquand holding
###   d. Number of ILLiad requests
###   e. Number of BorrowDirect requests [if possible to separate from general ILLiad requests]
###   f. Number of SCSB requests
###   g. SCSB Owning Institutions
###   h. SCSB Customer Codes
###   i. SCSB CGDs
output = File.open("#{output_dir}/marquand_borrowing_report_by_alma_holding.tsv", 'w')
output.write("MMS ID\tTitle\tHolding ID\tCall Number\tLocation\t")
output.write("ILLiad Requests\tBorrowDirect Requests\t")
output.puts("SCSB Requests\tSCSB Owning Institutions\tSCSB Customer Codes\tSCSB CGDs")
goldrush_to_mms_id.each do |key, mms_ids|
  scsb_partners = goldrush_to_partners[key]
  scsb_partners ||= {}
  ill_matches = goldrush_to_transaction_id[key].to_a
  ill_info = ill_matches.map { |trans_id| all_borrowing.find { |request| request.transaction_number == trans_id } }
  illiad_requests = ill_info.reject { |request| request.system_id == 'Reshare:princeton' }.size
  scsb_info = info_from_scsb_partners(scsb_partners)
  scsb_requests = request_count_from_partners(scsb_partners: scsb_partners, requests_per_barcode: requests_per_barcode)
  bd_requests = ill_info.select { |request| request.system_id == 'Reshare:princeton' }.size
  mms_ids.each do |mms_id|
    mms_info = bib_info[mms_id]
    mms_info[:holdings].each do |holding|
      output.write("#{mms_id}\t")
      output.write("#{mms_info[:title]}\t")
      output.write("#{holding[:id]}\t")
      output.write("#{holding[:call_num].full_call_num.strip}\t")
      output.write("#{holding[:location]}\t")
      output.write("#{illiad_requests}\t")
      output.write("#{bd_requests}\t")
      output.write("#{scsb_requests}\t")
      output.write("#{scsb_info[:owning_institutions].join(' | ')}\t")
      output.write("#{scsb_info[:customer_codes].join(' | ')}\t")
      output.puts(scsb_info[:cgds].join(' | '))
    end
  end
end
output.close

### A second report was requested to show number of requests per year
### Raw data should be the following:
###   1. MMS ID
###   2. Request date [creation date]
###   3. Year of request
###   4. Type of request
File.open("#{output_dir}/marquand_borrowing_report_requests_by_date.tsv", 'w') do |output|
  output.puts("MMS ID\tRequest Date\tYear of Request\tType of Request")
  goldrush_to_mms_id.each do |key, mms_ids|
    scsb_partners = goldrush_to_partners[key]
    scsb_partners ||= {}
    ill_matches = goldrush_to_transaction_id[key].to_a
    ill_info = ill_matches.map { |trans_id| all_borrowing.find { |request| request.transaction_number == trans_id } }
    illiad_requests = ill_info.reject { |request| request.transaction_info['SystemID'] == 'Reshare:princeton' }
    bd_requests = ill_info.select { |request| request.transaction_info['SystemID'] == 'Reshare:princeton' }
    scsb_info = info_from_scsb_partners(scsb_partners)
    scsb_requests = request_count_from_partners(scsb_partners: scsb_partners, requests_per_barcode: requests_per_barcode)
    mms_ids.each do |mms_id|
      illiad_requests.each do |request|
        output.write("#{mms_id}\t")
        output.write("#{request.creation_date}\t")
        output.write("#{request.creation_date.year}\t")
        output.puts("ILLiad")
      end
      bd_requests.each do |request|
        output.write("#{mms_id}\t")
        output.write("#{request.creation_date}\t")
        output.write("#{request.creation_date.year}\t")
        output.puts("BorrowDirect")
      end
      scsb_partners.each_value do |bib_hash|
        bib_hash.values.flatten.each do |item|
          requests = requests_per_barcode[item[:barcode]].to_a
          requests.each do |request|
            output.write("#{mms_id}\t")
            output.write("#{request[:request_date]}\t")
            output.write("#{request[:request_date].year}\t")
            output.puts("SCSB")
          end
        end
      end
    end
  end
end
