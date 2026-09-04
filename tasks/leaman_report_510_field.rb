# frozen_string_literal: true

### Purpose of report and System(s) Involved: We are interested in any and all PUL catalog records
###   with ESTC numbers, located in the 510 field (ex: 510 4 a| ESTC c| N48145).
###   We would like items to be sorted first by the primary/umbrella record MMSID
###     the items may be contained in (located in the 773 0), followed by the the item level MMSID (001 field).

### List of fields contained in the report output:
###   MMSID (001)
###   Title (245)
###   Format [from leader]
###   Published/Created (260/264)
###   Description (300)
###   Call No. from holding
###   Host record ID (773)
###   References - this is where the ESTC number is (510)
###   Title of Host record
###   Notes (500)
###   Library code
###   Location Code
###   Holding ID
###   Item ID

### Additional Information: Example record: https://catalog.princeton.edu/catalog/9936513653506421.
### We are interetested in finding all PUL Special Collections materials
###   that have been identified with ESTC numbers as we prepare a project for digitization.
require_relative '../lib/lsp-data'

def notes(record)
  record.fields('500').map(&:to_s).map { |string| string.gsub(/\s+/, ' ') }.join(' | ')
end

def write_pub_info_to_report(output, publisher)
  output.write("#{publisher[:pub_place]&.gsub(/\s+/, ' ')}\t")
  output.write("#{publisher[:pub_name]&.gsub(/\s+/, ' ')}\t")
  output.write("#{publisher[:pub_date]&.gsub(/\s+/, ' ')}\t")
end

def write_info_to_report(output:, info:, mms_id:, holding_id:)
  output.write("#{mms_id}\t#{holding_id}\t#{info[:format]}\t")
  output.write("#{info[:title]}\t#{info[:description]}\t#{info[:estc]}\t#{info[:notes]}\t")
  write_pub_info_to_report(output, info[:publisher])
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)
Time.new.strftime('%Y-%m-%d')
inst_suffix = ENV.fetch('ALMA_INST_SUFFIX', nil)
### Host records need the title, 774 MMS IDs, library codes, location codes,
###   note fields, holding IDs, and item IDs
host_records = {} # MMS ID is the key

### ESTC records need the title, 773 MMS IDs, library codes, location codes,
###   holding IDs, item IDs, 510 fields with ESTC, 500 fields, description, publisher info
estc_records = {} # MMS ID is the key
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    f774 = record.fields('774').select { |field| field['w'] =~ /^99[0-9]+#{inst_suffix}$/ }
    estc = record.fields('510').select { |field| field['a'] =~ /^ESTC/ }
    next if f774.empty? && estc.empty?

    f773 = record.fields('773').select { |field| field['w'] =~ /^99[0-9]+#{inst_suffix}$/ }
    f852 = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+#{inst_suffix}$/ }
    callnums = call_num_from_alma_holding_field(record: record, field_tag: '852',
                                                inst_suffix: inst_suffix, lc_only: false)
    location_info = {}
    f852.each do |field|
      location_info[field['8']] = { library: field['b'], location: field['c'] }
    end
    items_per_holding = {}
    record.fields('876').select { |field| field['a'] =~ /^23[0-9]+#{inst_suffix}$/ }.each do |field|
      items_per_holding[field['0']] ||= []
      items_per_holding[field['0']] << { id: field['a'], barcode: field['p'] }
    end
    info = { f774: f774.map { |field| field['w'] }, estc: estc.map(&:to_s).join(' | '),
             title: title(record), description: description(record),
             publisher: publisher(record), f773: f773.map { |field| field['w'] },
             notes: notes(record), format: record.leader[6..7],
             items: items_per_holding, location_info: location_info, callnums: callnums }
    host_records[record['001'].value] = info if f774.size.positive?
    estc_records[record['001'].value] = info if estc.size.positive?
  end
end

### Go through the ESTC records;
###   1. Look for host matches from the 773 fields
###   2. If there are host matches, include host info in the output
### Then go through the host records and see if the constituent IDs listed match ESTC records;
###   do not output the host record info if it was already output from the ESTC run

output = File.open("#{output_dir}/leaman_estc_report.tsv", 'w')
output.write("Host MMS ID\tHost Title\tItem MMS ID\tHolding ID\tFormat\tItem Title\t")
output.write("Description\tESTC Fields\tNotes\tPub Place\tPublisher\tPub Date\t")
output.puts("Library Code\tLocation Code\tCall Number\tItem ID\tBarcode")
records_processed = Set.new # put the MMS ID processed as an ESTC record to avoid duplicate output

# rubocop:disable Metrics/BlockLength
estc_records.each do |mms_id, info|
  host_records.slice(*info[:f773]).each do |host_id, host_info|
    host_info[:location_info].each do |holding_id, location|
      holding_items = host_info[:items][holding_id]
      call_num = host_info[:callnums][holding_id]&.full_call_num
      holding_items&.each do |item|
        output.write("#{host_id}\t#{host_info[:title]}\t")
        write_info_to_report(output: output, info: info, mms_id: mms_id, holding_id: holding_id)
        output.puts("#{location[:library]}\t#{location[:location]}\t#{call_num}\t#{item[:id]}\t#{item[:barcode]}")
      end
      next if holding_items

      output.write("#{host_id}\t#{host_info[:title]}\t")
      write_info_to_report(output: output, info: info, mms_id: mms_id, holding_id: holding_id)
      output.puts("#{location[:library]}\t#{location[:location]}\t#{call_num}\t\t")
    end
  end
  info[:location_info].each do |holding_id, location|
    holding_items = info[:items][holding_id]
    call_num = info[:callnums][holding_id]&.full_call_num
    holding_items&.each do |item|
      output.write("\t\t")
      write_info_to_report(output: output, info: info, mms_id: mms_id, holding_id: holding_id)
      output.puts("#{location[:library]}\t#{location[:location]}\t#{call_num}\t#{item[:id]}\t#{item[:barcode]}")
    end
    if holding_items.nil?
      output.write("\t\t")
      write_info_to_report(output: output, info: info, mms_id: mms_id, holding_id: holding_id)
      output.puts("#{location[:library]}\t#{location[:location]}\t#{call_num}\t\t")
    end
    records_processed << mms_id
  end
end
# rubocop:enable Metrics/BlockLength

host_records.each do |host_id, host_info|
  next if records_processed.include?(host_id)

  host_info[:location_info].each do |holding_id, location|
    holding_items = host_info[:items][holding_id]
    call_num = host_info[:callnums][holding_id]&.full_call_num
    estc_records.slice(*host_info[:f774]).each do |mms_id, info|
      holding_items&.each do |item|
        output.write("#{host_id}\t#{host_info[:title]}\t")
        write_info_to_report(output: output, info: info, mms_id: mms_id, holding_id: holding_id)
        output.puts("#{location[:library]}\t#{location[:location]}\t#{call_num}\t#{item[:id]}\t#{item[:barcode]}")
      end
      next if holding_items

      output.write("#{host_id}\t#{host_info[:title]}\t")
      write_info_to_report(output: output, info: info, mms_id: mms_id, holding_id: holding_id)
      output.puts("#{location[:library]}\t#{location[:location]}\t#{call_num}\t\t")
    end
  end
end
output.close
