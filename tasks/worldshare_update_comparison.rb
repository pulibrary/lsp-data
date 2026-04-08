# frozen_string_literal: true

### Compare records from Alma Sandbox that were enhanced by the new WorldShare Record Update
###   process to the same records in production

### To enable this comparison using 2 different sources (raw bib export for sandbox, full dump for prod),
###   fields potentially added from holdings and items need to be stripped
require_relative '../lib/lsp-data'

### Fields that can be changed from the WorldShare Record Update process:
###   Leader
###   010-029
###   041
###   050
###   400, 410, 411, 440, 490
###   800, 810, 811, 830
###   600-699 excluding 655
###   880s of the 4XX, 6XX (minus 655), and 8XX fields
def delete_unwanted_fields(record)
  record.fields.delete_if { |field| %w[005 852 866 867 868 583 876].include?(field.tag) }
  record.fields.delete_if { |field| field.tag[0] == '9' }
  record
end

def map_fields(record)
  eligible_fields = record.fields.reject { |field| field.tag == '035' }
  eligible_fields.map { |field| field.to_s.gsub(/\s/, ' ') } +
    ["LDR #{record.leader[5..11]}#{record.leader[17..]}"]
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

sandbox_records = {}
reader = MARC::XMLReader.new("#{input_dir}/changed_worldshare_recs.xml", parser: 'magic', ignore_namespace: true)
reader.each do |record|
  sandbox_records[record['001'].value] = delete_unwanted_fields(record)
end

### Export the bibs from prod that match the MMS IDs of the above file
prod_records = {}
MARC::XMLReader.new("#{input_dir}/prod_worldshare_recs.xml", parser: 'magic', ignore_namespace: true).each do |record|
  mms_id = record['001'].value
  prod_records[mms_id] = delete_unwanted_fields(record) if sandbox_records[mms_id]
end

rec_num = 0
fnum = 1
filestub = 'worldshare_comparison_04-2026'
output = nil
prod_records.each do |mms_id, original|
  if (rec_num % 75_000).zero?
    output&.close
    output = File.open("#{output_dir}/#{filestub}_#{fnum}.tsv", 'w')
    output.puts("MMS ID\tAction\tField Tag\tField Value")
    fnum += 1
  end
  changed = sandbox_records[mms_id]
  new_oclcs = oclcs(record: changed, output_prefix: true)
  old_oclcs = oclcs(record: original, output_prefix: true)
  original_fields = map_fields(original)
  changed_fields = map_fields(changed)
  original_fields += old_oclcs.map { |num| "035    $a#{num}" }
  changed_fields += new_oclcs.map { |num| "035    $a#{num}" }
  new_fields = changed_fields - original_fields
  removed_fields = original_fields - changed_fields
  new_fields.each do |field_string|
    tag = field_string.gsub(/^([^\s]+)\s.*$/, '\1')
    output.puts("#{mms_id}\tadd\t#{tag}\t#{field_string}")
  end
  removed_fields.each do |field_string|
    tag = field_string.gsub(/^([^\s]+)\s.*$/, '\1')
    output.puts("#{mms_id}\tremove\t#{tag}\t#{field_string}")
  end
  rec_num += 1
end
output.close
