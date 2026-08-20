# frozen_string_literal: true

### Evaluate changes made to records as part of the WorldShare Record Update process
### Replicate the actions of the norm rule used on the incoming OCLC record and
###   the merge rule used to merge data into Alma
require_relative '../lib/lsp-data'
require 'csv'

### Fields that can be changed from the WorldShare Record Update process:
###   Leader (replace positions 6-23)
###   010-029 (replace)
###   041 (replace if exists in OCLC)
###   050 (add if no 050 in Alma)
###   400, 410, 411, 440, 490 (replace)
###   800, 810, 811, 830 (replace)
###   600-699 excluding 655 (replace)
###   880s of the 0XX, 4XX, 6XX (minus 655), and 8XX fields (replace)

### Exclude all 6XX and 8XX fields from OCLC with $5, even NjP ones
### Remove 050 fields from OCLC if there is no $b
### Protect all existing 6XX and 8XX in Alma if there is $5 NjP

### Only process monographs from OCLC (leader position 7 is `m`)

### Methods to process the Alma record
def delete_management_tags(record)
  record.fields.delete_if { |field| %w[950 952].include?(field.tag) }
  record
end

def delete_oclc_fields(record)
  record.fields.delete_if { |field| field.tag == '035' && field['a'] =~ /OCoLC/ }
  record
end

def delete_inventory_fields(record)
  record.fields.delete_if do |field|
    (%w[852 866 867 868 583].include?(field.tag) && field['8'] =~ /6421$/) ||
      (%w[876 951].include?(field.tag) && field['0'] =~ /6421$/) ||
      (%w[953 954].include?(field.tag) && field['a'] =~ /6421$/)
  end
  record
end

def delete_unwanted_f880(record)
  record.fields.delete_if do |field|
    field.tag == '880' && field['5'] != 'NjP' && field['6'] =~ /^[0 468]/ && field['6'] !~ /^655/
  end
  record
end

def delete_conditional_fields(record)
  delete_unwanted_f880(record)
  record.fields.delete_if do |field|
    (wanted_f6xx_tags.include?(field.tag) && field['5'] != 'NjP') ||
      (%w[800 810 811 830].include?(field.tag) && field['5'] != 'NjP')
  end
  record
end

def delete_unwanted_alma_fields(record)
  record.fields.delete_if { |field| (('010'..'029').to_a + %w[400 410 411 440 490]).include?(field.tag) }
  delete_management_tags(record)
  delete_inventory_fields(record)
  delete_oclc_fields(record)
  delete_conditional_fields(record)
  record
end

def fields_from_alma(record)
  record = remove_uris_from_record(record)
  {
    leader: "00000c#{record.leader[6..11]}00000#{record.leader[17..23]}",
    oclcs: oclcs(record: record),
    fields: [
      record.fields('010'..'029'),
      record.fields(%w[041 050 400 410 411 440 490 800 810 811 830 880]),
      wanted_f6xx_with_subf5(record)
    ].flatten.map(&:to_s)
  }
end

def update_f041_fields(record, new_fields)
  if new_fields.size.positive?
    record.fields.delete_if { |field| field.tag == '041' }
    new_fields.each { |field| record.append(field) }
  end
  record
end

def update_f050_fields(record, new_fields)
  new_fields.each { |field| record.append(field) } unless record['050']
  record
end

def append_unconditional_fields(record, new_fields)
  new_fields[:f0xx].each { |field| record.append(field) }
  new_fields[:f4xx].each { |field| record.append(field) }
  new_fields[:f6xx].each { |field| record.append(field) }
  new_fields[:f8xx].each { |field| record.append(field) }
  new_fields[:f880].each { |field| record.append(field) }
  record
end

def add_oclc_fields(record:, oclc_num:, new_fields:)
  record.append(new_oclc_field(oclc_num))
  record.leader = record.leader[0..5] + new_fields[:leader][6..]
  record = update_f041_fields(record, new_fields[:f041])
  record = update_f050_fields(record, new_fields[:f050])
  record = append_unconditional_fields(record, new_fields)
  record.append(new_fields[:f916])
  record
end

def update_alma_record(record:, new_fields:, oclc_num:)
  record = delete_unwanted_alma_fields(record)
  add_oclc_fields(record: record, oclc_num: oclc_num, new_fields: new_fields)
end

### Methods to identify elements to bring in from OCLC
def valid_oclc_record?(record)
  record.leader[7] == 'm'
end

def wanted_f880(record)
  record.fields('880').select do |field|
    field['6'] &&
      field['6'][0..2] != '655' &&
      (%w[0 4].include?(field['6'][0]) || (%w[6 8].include?(field['6'][0]) && field['5'].nil?))
  end
end

def wanted_f6xx_tags
  ('600'..'699').to_a - %w[655]
end

def wanted_f6xx(record)
  record.fields(wanted_f6xx_tags).reject { |field| field['5'] }
end

def wanted_f6xx_with_subf5(record)
  record.fields(wanted_f6xx_tags)
end

def fields_from_oclc(record)
  {
    leader: record.leader,
    f0xx: record.fields('010'..'029'),
    f041: record.fields('041'), f050: record.fields('050').select { |field| field['b'] },
    f4xx: record.fields(%w[400 410 411 440 490]),
    f6xx: wanted_f6xx(record),
    f8xx: record.fields(%w[800 810 811 830]).reject { |field| field['5'] },
    f880: wanted_f880(record),
    f916: record.fields('916').first
  }
end

def remove_uris_from_record(record)
  record.fields('010'..'880').each do |field|
    field.subfields.delete_if { |subfield| %w[0 1].include?(subfield.code) }
  end
  record
end

def all_xref(record)
  xref = []
  record.fields('019').each do |field|
    field.subfields.each do |subfield|
      xref << subfield.value if subfield.code == 'a'
    end
  end
  xref
end

def new_oclc_field(oclc_num)
  MARC::DataField.new('035', ' ', ' ', MARC::Subfield.new('a', "(OCoLC)#{oclc_num}"))
end

### Methods related to report output
def output_changed_fields(output:, pre:, post:, mms_id:)
  (post - pre).each do |field|
    tag = field[0..2]
    output.puts("#{mms_id}\tAdd\t#{tag}\t#{field}")
  end
  (pre - post).each do |field|
    tag = field[0..2]
    output.puts("#{mms_id}\tRemove\t#{tag}\t#{field}")
  end
end

def output_changed_oclc(output:, pre:, post:, mms_id:)
  (post - pre).each do |oclc_num|
    output.puts("#{mms_id}\tAdd\tOCLC\t#{oclc_num}")
  end
  (pre - post).each do |oclc_num|
    output.puts("#{mms_id}\tRemove\tOCLC\t#{oclc_num}")
  end
end

def output_changed_leader(output:, pre:, post:, mms_id:)
  return unless post != pre

  output.puts("#{mms_id}\tRemove\tLeader\t#{pre}")
  output.puts("#{mms_id}\tAdd\tLeader\t#{post}")
end

def tag_for_field_report(field_value:, tag:)
  if (%w[653 654 656 657 658 662 688] + ('690'..'699').to_a).include?(tag)
    "#{tag}_non_lc"
  elsif %w[600 610 611 630 647 648 650 651 655].include?(tag)
    field_value[5] == '0' ? "#{tag}_lc" : "#{tag}_non_lc"
  else
    tag
  end
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Create a concordance of every crossref OCLC number to the definitive OCLC number
### Iterate through a full prod dump of Alma and perform the required field operations;
### Write out the records for ingesting later to evaluate the changes

# rubocop:disable Metrics/BlockLength
('0'..'9').each do |num|
  xref_to_oclc_num = {}
  oclc_fields = {} # OCLC number is the key, the target fields will be in the value
  Dir.glob("#{input_dir}/pul_oclc/metacoll*#{num}.mrc").each do |file|
    MARC::Reader.new(file).each do |record|
      next unless valid_oclc_record?(record)

      oclc_num = oclcs(record: record).first
      all_xref(record).each { |xref| xref_to_oclc_num[xref] = oclc_num }
      oclc_fields[oclc_num] = fields_from_oclc(record)
    end
  end

  all_xref_nums = Set.new(xref_to_oclc_num.keys)
  all_oclc_nums = Set.new(oclc_fields.keys)
  writer = MARC::XMLWriter.new("#{output_dir}/new_changed_prod_records_batch#{num}.marcxml")
  output = File.open("#{output_dir}/new_worldshare_differences_#{num}.tsv", 'w')
  output.puts("MMS ID\tAction\tField\tValue")
  Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
    MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
      next if record.fields('035').any? { |field| field['a'] =~ /^\(CKB\)/ } # CZ records

      all_oclcs = Set.new(oclcs(record: record) + all_xref(record))
      oclc_match = all_oclcs.intersection(all_oclc_nums).first
      xref_match = all_oclcs.intersection(all_xref_nums).first
      next unless oclc_match || xref_match

      mms_id = record['001'].value
      oclc_num = oclc_match || xref_to_oclc_num[xref_match]
      original_record = duplicate_record(record)
      pre = fields_from_alma(original_record)
      record = update_alma_record(record: record, new_fields: oclc_fields[oclc_num], oclc_num: oclc_num)
      writer.write(record)
      post = fields_from_alma(record)
      output_changed_leader(output: output, pre: pre[:leader], post: post[:leader], mms_id: mms_id)
      output_changed_oclc(output: output, pre: pre[:oclcs], post: post[:oclcs], mms_id: mms_id)
      output_changed_fields(output: output, pre: pre[:fields], post: post[:fields], mms_id: mms_id)
    end
  end
  writer.close
  output.close
end
# rubocop:enable Metrics/BlockLength

### Show all changes other than series and subjects
field_count = 0
csv = CSV.open("#{output_dir}/other_worldshare_differences_1.csv", 'w', force_quotes: true)
csv << ['MMS ID', 'Action', 'Field', 'Value']
fnum = 1
Dir.glob("#{input_dir}/worldshare_differences_*.tsv").each do |file|
  File.open(file, 'r') do |input|
    input.gets
    changes_by_mms_id = {}
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      next if parts[3][0] == '6' || %w[400 410 411 440 490 800 810 811 830].include?(parts[3][0..2])

      changes_by_mms_id[parts[0]] ||= []
      changes_by_mms_id[parts[0]] << parts
    end
    changes_by_mms_id.each_value do |fields|
      if field_count > 800_000
        csv.close
        fnum += 1
        csv = CSV.open("#{output_dir}/other_worldshare_differences_#{fnum}.csv", 'w', force_quotes: true)
        csv << ['MMS ID', 'Action', 'Field', 'Value']
        field_count = 0
      end
      field_count += fields.size
      fields.each { |field| csv << field }
    end
  end
end
csv.close

### Show all series changes
field_count = 0
csv = CSV.open("#{output_dir}/series_worldshare_differences_1.csv", 'w', force_quotes: true)
csv << ['MMS ID', 'Action', 'Field', 'Value']
fnum = 1
Dir.glob("#{input_dir}/worldshare_differences_*.tsv").each do |file|
  File.open(file, 'r') do |input|
    input.gets
    changes_by_mms_id = {}
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      next unless %w[400 410 411 440 490 800 810 811 830].include?(parts[3][0..2])

      changes_by_mms_id[parts[0]] ||= []
      changes_by_mms_id[parts[0]] << parts
    end
    changes_by_mms_id.each_value do |fields|
      if field_count > 800_000
        csv.close
        fnum += 1
        csv = CSV.open("#{output_dir}/series_worldshare_differences_#{fnum}.csv", 'w', force_quotes: true)
        csv << ['MMS ID', 'Action', 'Field', 'Value']
        field_count = 0
      end
      field_count += fields.size
      fields.each { |field| csv << field }
    end
  end
end
csv.close

### Subject-heading focused report; only show LCSH changes
field_count = 0
csv = CSV.open("#{output_dir}/lcsh_worldshare_differences_1.csv", 'w', force_quotes: true)
csv << ['MMS ID', 'Action', 'Field', 'Value']
fnum = 1
Dir.glob("#{input_dir}/worldshare_differences_*.tsv").each do |file|
  File.open(file, 'r') do |input|
    input.gets
    changes_by_mms_id = {}
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      tag = tag_for_field_report(field_value: parts[3], tag: parts[2])
      next unless tag =~ /[0-9]_lc$/

      changes_by_mms_id[parts[0]] ||= []
      changes_by_mms_id[parts[0]] << parts
    end
    changes_by_mms_id.each_value do |fields|
      if field_count > 800_000
        csv.close
        fnum += 1
        csv = CSV.open("#{output_dir}/lcsh_worldshare_differences_#{fnum}.csv", 'w', force_quotes: true)
        csv << ['MMS ID', 'Action', 'Field', 'Value']
        field_count = 0
      end
      field_count += fields.size
      fields.each { |field| csv << field }
    end
  end
end
csv.close

### Subject-heading focused report; only show non-LCSH changes
field_count = 0
csv = CSV.open("#{output_dir}/no_lcsh_worldshare_differences_1.csv", 'w', force_quotes: true)
csv << ['MMS ID', 'Action', 'Field', 'Value']
fnum = 1
Dir.glob("#{input_dir}/worldshare_differences_*.tsv").each do |file|
  File.open(file, 'r') do |input|
    input.gets
    changes_by_mms_id = {}
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      tag = tag_for_field_report(field_value: parts[3], tag: parts[2])
      next unless tag =~ /non_lc$/

      changes_by_mms_id[parts[0]] ||= []
      changes_by_mms_id[parts[0]] << parts
    end
    changes_by_mms_id.each_value do |fields|
      if field_count > 800_000
        csv.close
        fnum += 1
        csv = CSV.open("#{output_dir}/no_lcsh_worldshare_differences_#{fnum}.csv", 'w', force_quotes: true)
        csv << ['MMS ID', 'Action', 'Field', 'Value']
        field_count = 0
      end
      field_count += fields.size
      fields.each { |field| csv << field }
    end
  end
end
csv.close

### Changes to 880 fields or non-880 fields with $6
field_count = 0
csv = CSV.open("#{output_dir}/880_worldshare_differences_1.csv", 'w', force_quotes: true)
csv << ['MMS ID', 'Action', 'Field', 'Value']
fnum = 1
Dir.glob("#{input_dir}/worldshare_differences_*.tsv").each do |file|
  File.open(file, 'r') do |input|
    input.gets
    changes_by_mms_id = {}
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      next unless parts[3] =~ /^880|\$6 [0-9]/

      changes_by_mms_id[parts[0]] ||= []
      changes_by_mms_id[parts[0]] << parts
    end
    changes_by_mms_id.each_value do |fields|
      if field_count > 800_000
        csv.close
        fnum += 1
        csv = CSV.open("#{output_dir}/880_worldshare_differences_#{fnum}.csv", 'w', force_quotes: true)
        csv << ['MMS ID', 'Action', 'Field', 'Value']
        field_count = 0
      end
      field_count += fields.size
      fields.each { |field| csv << field }
    end
  end
end
csv.close

### Produce summary of number of added and removed fields per field tag
File.open("#{output_dir}/worldshare_update_field_summary.tsv", 'w') do |output|
  output.puts("Tag\tNumber Added\tNumber Removed")
  changes_per_tag = {}
  Dir.glob("#{input_dir}/worldshare_differences_*.tsv").each do |file|
    File.open(file, 'r') do |input|
      input.gets
      while (line = input.gets)
        line.chomp!
        parts = line.split("\t")
        tag = tag_for_field_report(field_value: parts[3], tag: parts[2])
        changes_per_tag[tag] ||= { add: 0, remove: 0 }
        case parts[1] # action
        when 'Add'
          changes_per_tag[tag][:add] += 1
        else
          changes_per_tag[tag][:remove] += 1
        end
      end
    end
  end
  changes_per_tag.each do |tag, actions|
    output.write("#{tag}\t")
    output.write("#{actions[:add]}\t")
    output.puts(actions[:remove])
  end
end
