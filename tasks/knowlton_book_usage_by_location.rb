# frozen_string_literal: true

### Find monographic print books with a  copyright date of 2015-2023.
### Each copy should be its own line.
### Data to include:
###   MMS ID
###   Title
###   Year of Publication (date1 from 008)
###   Holding ID
###   LC Call Number parsed by main LC class, LC subclass, classification number,
###     and full call number; if no LC call number in holdings, check 050 in bib
###   Library code
###   Location code
###   Item ID
###   Item description
###   Item barcode
###   Number of loans
###   Number of browses (called "In-House Loans" in Alma)

###  Include usage from 7/1/23 to 6/30/25
require_relative '../lib/lsp-data'
require 'csv'

def preferred_call_num(record:, holding_id:)
  holding = call_num_from_alma_holding_field(record: record,
                                             field_tag: '852',
                                             inst_suffix: '6421')[holding_id]
  return holding if holding

  bib050 = call_num_from_bib_field(record: record, field_tag: '050').find(&:lc?)
  return bib050 if bib050

  call_num_from_bib_field(record: record, field_tag: '090').find(&:lc?)
end

def date_from_f008(record)
  return 0 unless record['008'] && record['008'].value.size > 11

  date1 = record['008'].value[7..10].gsub('u', '0')
  date1.to_i
end

def valid_record?(record)
  record.leader[5] != 'd' && record.leader[6..7] == 'am'
end

def relevant_item_fields(record)
  record.fields('876').select do |field|
    field['a'] =~ /^23[0-9]+6421$/ &&
      field['p'].to_s != '' &&
      record.fields('852').any? { |f852| f852['8'] == field['0'] }
  end
end

def item_info(item_field:, record:)
  holding_id = item_field['0']
  holding_field = record.fields('852').find { |field| field['8'] == holding_id }
  {
    holding_id: holding_id, library: holding_field['b'], location: holding_field['c'],
    item_id: item_field['a'], barcode: item_field['p'], description: item_field['3'],
    call_num: preferred_call_num(record: record, holding_id: holding_id)
  }
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Retrieve usage for all items from 7/1/23 to 6/30/25 in Analytics
usage_by_item = {}
csv = CSV.open("#{input_dir}/All Items With Usage FY23 to FY25.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  usage_by_item[row['Physical Item Id']] = {
    in_house: row['Loans (In House)'],
    loans: row['Loans (Not In House)']
  }
end

### Go through the full dump and report out records with usage with the following criteria
###   Is a monograph
###   Is textual material
###   Has date1 value between 2015 and 2023
###   Has an LC call number
###   Has a barcode
output = File.open("#{output_dir}/knowlton_book_usage_by_location.tsv", 'w')
output.write("MMS ID\tTitle\tYear of Publication\tHolding ID\t")
output.write("LC Main Class\tLC Full Class\tLC Classification Number\tFull LC Call Number\t")
output.write("Library Code\tLocation Code\tItem ID\tItem Description\tItem Barcode\t")
output.puts("Number of Loans\tNumber of Browses")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next unless valid_record?(record)

    date = date_from_f008(record)
    next unless date.between?(2015, 2023)

    mms_id = record['001'].value
    title = title(record)
    relevant_item_fields(record).each do |item_field|
      info = item_info(item_field: item_field, record: record)
      output.write("#{mms_id}\t#{title}\t#{date}\t#{info[:holding_id]}\t")
      if info[:call_num]
        output.write("#{info[:call_num].primary_lc_class}\t#{info[:call_num].sub_lc_class}\t")
        output.write("#{info[:call_num].classification}\t#{info[:call_num].full_call_num}\t")
      else
        output.write("\t\t\t\t")
      end
      output.write("#{info[:library]}\t#{info[:location]}\t#{info[:item_id]}\t")
      output.write("#{info[:description]}\t#{info[:barcode]}\t")
      usage = usage_by_item[info[:item_id]]
      if usage
        output.puts("#{usage[:loans]}\t#{usage[:in_house]}")
      else
        output.puts("0\t0")
      end
    end
  end
end
output.close

### Produce summaries based on the full report, to avoid having to look at raw data
### Usage by location, LC Class, and year
###   a. Total number of items used at all
###   b. Total number of items not used at all
###   c. Total loans
###   d. Total browses
location_hash = {} # Library, locations, Main Class, Full Class, Class Number, Year, Items
File.open("#{output_dir}/knowlton_book_usage_by_location.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    library = parts[8]
    location = parts[9]
    main_class = parts[4] == '' ? 'Undefined' : parts[4]
    full_class = parts[5] == '' ? 'Undefined' : parts[5]
    class_num = parts[6] == '' ? 'Undefined' : parts[6]
    item_id = parts[10]
    year = parts[2]
    usage_hash = { loans: parts[13].to_i, browses: parts[14].to_i }
    location_hash[library] ||= {}
    location_hash[library][location] ||= {}
    location_hash[library][location][main_class] ||= {}
    location_hash[library][location][main_class][full_class] ||= {}
    location_hash[library][location][main_class][full_class][class_num] ||= {}
    location_hash[library][location][main_class][full_class][class_num][year] ||= {}
    location_hash[library][location][main_class][full_class][class_num][year][item_id] = usage_hash
  end
end

File.open("#{output_dir}/knowlton_book_usage_by_location_summary.tsv", 'w') do |output|
  output.write("Library\tLocation\tLC Main Class\tLC Full Class\tLC Classification Number\t")
  output.puts("Year of Publication\tItems With Usage\tItems with No Usage\tTotal Loans\tTotal Browses")
  location_hash.each do |library, loc_info|
    loc_info.each do |location, main|
      main.each do |main_class, full|
        full.each do |full_class, num|
          num.each do |class_num, years|
            years.each do |year, items|
              no_usage = items.select { |_id, usage| (usage[:loans] + usage[:browses]).zero? }.size
              has_usage = items.reject { |_id, usage| (usage[:loans] + usage[:browses]).zero? }.size
              loans = items.values.map { |usage| usage[:loans] }.sum
              browses = items.values.map { |usage| usage[:browses] }.sum
              output.write("#{library}\t#{location}\t#{main_class}\t")
              output.write("#{full_class}\t#{class_num}\t#{year}\t")
              output.puts("#{has_usage}\t#{no_usage}\t#{loans}\t#{browses}")
            end
          end
        end
      end
    end
  end
end
