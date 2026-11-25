# frozen_string_literal: true

# I need to cross reference 1,500 potential bibliographic acquisitions for Special Collections.
# To simplify this work, I am hoping to receive an excel spreadsheet of
#   bibliographic records from the catalog.
# These would be print (book) records held by Special Collections for the years
#   1700 and 1900.
# If there is a way to limit the report to books published in the United States
#   and/or New Jersey, that would be very useful, however,
#   if that introduces inconsistent results
#   (i.e., appropriate records are not included due to old cataloging practices),
#   I would rather have all the data from which to sort and compare records.

# Fields desired: Author(s), Title, Publishing Location, Publisher, Year,
#   Call Number, biblink URL.
require_relative '../lib/lsp-data'

def holdings_from_record(record)
  record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
end

def eligible_record?(record)
  record.leader[5] != 'd' &&
    %w[a t].include?(record.leader[6]) &&
    record['008']&.value =~ /^.{7}1[78]|^.{7}1900|^.{7}19u/
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Go through a full dump and find all print textual material records
###   that have date1 between 1700 and 1900; also include dates of 17[0-9u]u and 19uu
### Include the locations as well
### Also gather all the host IDs from all records in those date ranges to allow
###   searching for bound-withs as well
constituent_to_hosts = {}
target_records = {} # MMS ID, with the full MARC record
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next unless eligible_record?(record)

    mms_id = record['001'].value
    target_records[mms_id] = record
    record.fields('773').select { |field| field['w'] =~ /^99[0-9]+6421$/ }.each do |field|
      constituent_to_hosts[mms_id] ||= []
      constituent_to_hosts[mms_id] << field['w']
    end
  end
end

all_hosts = Set.new(constituent_to_hosts.values.flatten)
host_records = {}
### Get host records from a full dump
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  break if all_hosts.size == host_records.size

  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    mms_id = record['001'].value
    next unless all_hosts.include?(mms_id)

    host_records[mms_id] = record
  end
end

### Produce report
output = File.open("#{output_dir}/swift_rare_books_report.tsv", 'w')
header_row = "Catalog Link\tAuthor\tTitle\tPublishing Location\tPublisher\tPublisher Year\t".dup
header_row << "Date1\tHolding ID\tOwning Library\tLocation\tCall Number"
output.puts(header_row)
target_records.each_value do |record|
  holdings = holdings_from_record(record)
  hosts = record.fields('773').select { |field| field['w'] =~ /^99[0-9]+6421$/ }.map { |field| field['w'] }
  hosts.uniq!
  unless hosts.empty?
    hosts.each do |host|
      host_record = host_records[host]
      holdings += holdings_from_record(host_record) if host_record
    end
  end
  rare_mudd = holdings.select { |field| %w[rare mudd].include?(field['b']) }
  next if rare_mudd.empty?

  pub_info = publisher(record)
  author = author(record)
  title = title(record)
  rare_mudd.each do |holding|
    call_num = ParsedCallNumber.new(primary_subfield: holding.subfields.find { |s| s.code == 'h' },
                                    item_subfields: holding.subfields.select { |s| s.code == 'i' },
                                    assume_lc: holding.indicator1 == '0').full_call_num
    call_num.prepend("#{holding['3']}: ") if holding['3']
    output.write("https://catalog.princeton.edu/catalog/#{record['001'].value}\t")
    output.write("#{author}\t#{title}\t")
    output.write("#{pub_info[:pub_place]}\t#{pub_info[:pub_name]}\t#{pub_info[:pub_date]}\t")
    output.write("#{record['008'].value[7..10]}\t")
    output.puts("#{holding['8']}\t#{holding['b']}\t#{holding['c']}\t#{call_num}")
  end
end
output.close
