# frozen_string_literal: true

### Steps to restore Valva records
### 1. Download all incremental delete files from publishing from 5/8/26 to today
### 2. Go through files from earliest to latest and save records to a hash with the word "Valva" in a 490 field
###   a. Replace the MARC record in the hash if a newer copy is found of the MMS ID
### 3. Add an 009 field to the records with the current MMS ID
### 4. Load the records into production with the MMS ID as a match point in case the record was previously restored
###  a. If a match is found, do not load the record
### 5. Export all records from production that have "Valva" in the series
### 6. Using the MMS IDs found in the 009 fields, make a concordance between the original MMS IDs and the new MMS IDs
### 7. Go through all tabs in the Google Sheet to see which MMS IDs don't exist, and which ones need to be updated
### 8. Generate new sheets and create an Excel Workbook with all 7 tabs from the original sheet
### 9. Remove 009 fields from Valva records
### 10. Unsuppress all Valva records
### 11. Add placeholder digital inventory for bibs that do not yet have inventory in Figgy
### 12. Delete obsolete `elf1` physical holdings
require_relative '../lib/lsp-data'
require 'csv'

def mms_id?(value)
  value =~ /^99[0-9]+6421$/ ? true : false
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

# Find deleted records, modify them, then export them for loading into Alma
mms_to_record = {}
Dir.glob("#{input_dir}/deletes/incremental*delete").sort_by { |file| File.new(file).mtime }.each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next unless record.fields('490').any? { |field| field['a'] =~ /Valva/ }

    record.leader[5] = 'c'
    mms_id = record['001'].value
    record.append(MARC::ControlField.new('009', mms_id))
    mms_to_record[mms_id] = record
  end
end
MARC::XMLWriter.new("#{output_dir}/valva_records_to_load.marcxml") do |writer|
  mms_to_record.each_value { |record| writer.write(record) }
end

# Create a concordance of MMS IDs; if there is no 009, the key and value are the same;
#   If there is an 009, the key is the 009 and the value is the 001
original_id_to_current = {}
MARC::XMLReader.new("#{input_dir}/all_valva_production.xml", parser: 'magic', ignore_namespace: true).each do |record|
  current_mms_id = record['001'].value
  original_mms_id = record['009'] ? record['009'].value : current_mms_id
  original_id_to_current[original_mms_id] = current_mms_id
end

File.open("#{output_dir}/valva_original_mms_to_current_mms.tsv", 'w') do |output|
  output.puts("Original MMS ID\tCurrent MMS ID")
  original_id_to_current.each do |original, current|
    next if original == current

    output.write("#{original}\t")
    output.puts(current)
  end
end
# Go through each of the sheets from the Valva progress Google Sheet and replace
#   the MMS ID with the new MMS ID; if the MMS ID is not found, log it
missing_mms_ids = []
Dir.glob("#{input_dir}/valva_progress*.csv").each do |file|
  headers = CSV.foreach(file).first.compact
  CSV.open(file, 'r', headers: true, encoding: 'bom|utf-8') do |csv|
    File.open("#{output_dir}/#{File.basename(file, '.csv')}_updated_prod.tsv", 'w') do |output|
      output.write(headers.join("\t"))
      output.puts('')
      csv.each do |row|
        row.reject { |key, _value| key.nil? }.each do |heading, value|
          value&.gsub!(/\s+/, ' ')
          if heading == 'Alma MMS ID'
            current_mms_id = original_id_to_current[value]
            if current_mms_id
              output.write("#{current_mms_id}\t")
            else
              missing_mms_ids << value
              value_to_output = mms_id?(value) ? "#{value}_problem" : value
              output.write("#{value_to_output}\t")
            end
          else
            output.write("#{value}\t")
          end
        end
        output.puts('')
      end
    end
  end
end
File.open("#{output_dir}/valva_missing_mms_ids.tsv", 'w') do |output|
  output.puts('MMS ID')
  missing_mms_ids.uniq.each do |id|
    output.puts(id) if id
  end
end
