# frozen_string_literal: true

### Report is generated from the most recent full dump
###   to find unsuppressed bibliographic records with
###   more than one unique location with the following information
###   - Leaders position 6-7 (type of record and bibliographic level)
###   - MMS ID
###   - Holding ID
###   - 852$b (owning library)
###   - 852$c (location code)
###   - Count of items

require_relative './../lib/lsp-data'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

def record_info(record)
  {
    leader_info: record.leader[6..7],
    mms_id: record['001'].value
  }
end

def items_for_holding(holding_id:, record:)
  record.fields('876').select do |field|
    field['a'] =~ /^23[0-9]+6421$/ && field['0'] == holding_id
  end
end

def location_info(record)
  locations = {}
  f852 = record.fields('852').select { |f| f['8'] =~ /^22[0-9]+6421$/ }
  f852.each do |holding_field|
    location = "#{holding_field['b']}$#{holding_field['c']}"
    locations[location] ||= {}
    holding_id = holding_field['8']
    items = items_for_holding(holding_id: holding_id, record: record)
    locations[location][holding_id] = items.size
  end
  locations
end

File.open("#{output_dir}/bibs_with_multiple_locations.tsv", 'w') do |output|
  output.puts("MMS ID\tRecord Type\tHolding ID\tLibrary Code\tLocation Code\tNumber of Items")
  Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
    reader.each do |record|
      next if record.leader[5] == 'd'

      bib_info = record_info(record)
      locations = location_info(record)
      next if locations.size < 2

      locations.each do |location, holdings|
        holdings.each do |holding_id, item_count|
          output.write("#{bib_info[:mms_id]}\t")
          output.write("#{bib_info[:leader_info]}\t")
          output.write("#{holding_id}\t")
          location_parts = location.split('$')
          library_code = location_parts[0]
          location_code = location_parts[1]
          output.write("#{library_code}\t")
          output.write("#{location_code}\t")
          output.puts(item_count)
        end
      end
    end
  end
end
