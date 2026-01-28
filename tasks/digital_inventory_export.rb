# frozen_string_literal: true

require_relative '../lib/lsp-data'

output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Retrieve Figgy report via API call and save to a file

### Load Figgy report to create a hash of digital objects grouped by MMS ID
url = 'https://figgy.princeton.edu'
conn = api_conn(url)
auth_token = ENV.fetch('FIGGY_TOKEN', nil)
figgy_report = FiggyReport.new(conn: conn, auth_token: auth_token)
mms_to_objects = figgy_report.mms_hash

### Generate separate files of OAI MARC records for each repository_code value;
### If there are multiple objects of the same repository type,
###   must make separate records and load them in subsequent passes;
### The goal for the integration is to have one ARK that represents the entire object,
###   but users do not consistently enter metadata to achieve this easily
date = Date.today.strftime('%Y-%m-%d')
grouped_records = {}
mms_to_objects.each_value do |alma_objects|
  alma_objects.group_by(&:repository_code).each do |repository_code, objects|
    objects.each_with_index do |alma_object, index|
      grouped_records[repository_code] ||= {}
      grouped_records[repository_code][index] ||= []
      grouped_records[repository_code][index] << alma_object.record
    end
  end
end
on_campus_stub = "figgy_on_campus_#{date}"
open_stub = "figgy_open_#{date}"
private_stub = "figgy_private_#{date}"
princeton_stub = "figgy_princeton_#{date}"
reading_room_stub = "figgy_reading_room_#{date}"
grouped_records.each do |repository_code, file_indexes|
  file_indexes.each do |file_index, records|
    output = case repository_code
             when 'figgy-open'
               File.open("#{output_dir}/#{open_stub}_#{file_index}.xml", 'w')
             when 'figgy-private'
               File.open("#{output_dir}/#{private_stub}_#{file_index}.xml", 'w')
             when 'figgy-princeton'
               File.open("#{output_dir}/#{princeton_stub}_#{file_index}.xml", 'w')
             when 'figgy-reading_room'
               File.open("#{output_dir}/#{reading_room_stub}_#{file_index}.xml", 'w')
             when 'figgy-on_campus'
               File.open("#{output_dir}/#{on_campus_stub}_#{file_index}.xml", 'w')
             end
    output.puts('<ListRecords>')
    records.each { |record| output.puts(record) }
    output.puts('</ListRecords>')
    output.close
  end
end
