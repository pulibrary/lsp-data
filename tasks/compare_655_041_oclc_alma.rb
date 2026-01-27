# frozen_string_literal: true

### Scenarios to test:
###   1. Add 655 from OCLC except $2 rb*
###   2. 041:
###     a. Add if not exists in Alma
###     b. Replace if exists in OCLC, regardless of Alma
require_relative '../lib/lsp-data'

### `rb` form/genre vocabularies will be stripped from incoming OCLC records
def delete_unwanted_fields(record)
  record.fields.delete_if { |field| field.tag == '655' && field['2'] =~ /^rb/ }
  record.fields.delete_if { |field| field.tag == '655' && field['5'] && !%w[PUL NjP].include?(field['5']) }
  record
end

### CZ records will not be overlaid by this process; in addition, OCLC records
###   that are not monographs will be skipped
def wanted_alma_record?(record)
  oclc_nums = oclcs(record: record)
  cz = record.fields.any? { |f| f.tag == '035' && f['a'] =~ /^\(CKB\)/ }
  oclc_nums.size.positive? && record.leader[7] == 'm' && record.leader[5] != 'd' && cz == false
end

def wanted_oclc_record?(record)
  record.leader[7] == 'm'
end

def oclcs_with_obsolete(record:, input_prefix: true, output_prefix: false)
  oclc = []
  record.fields('035').select { |f| f['a'] }.each do |field|
    field.subfields.each do |subfield|
      next unless %w[a z].include?(subfield.code)

      value = oclc_normalize(oclc: subfield.value, input_prefix: input_prefix, output_prefix: output_prefix)
      oclc << value if value
    end
  end
  oclc.uniq
end

### Step 1: Produce reports with the following from Alma per row:
### MMS ID
### OCLC numbers in 035$a and 035$z (separated by pipe characters)
### 655 field

### MMS ID
### OCLC numbers in 035$a and 035$z (separated by pipe characters)
### 041 field

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

f041_out = File.open("#{output_dir}/alma_041_fields.tsv", 'w')
f655_out = File.open("#{output_dir}/alma_655_fields.tsv", 'w')
f041_out.puts("mms_id\toclc\tfield")
f655_out.puts("mms_id\toclc\tfield")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_alma_record?(record)

    mms_id = record['001'].value
    oclc_nums = oclcs_with_obsolete(record: record)
    record.fields('041').each do |field|
      f041_out.write("#{mms_id}\t")
      f041_out.write("#{oclc_nums.join('|')}\t")
      f041_out.puts(field.to_s)
    end
    record.fields('655').each do |field|
      f655_out.write("#{mms_id}\t")
      f655_out.write("#{oclc_nums.join('|')}\t")
      f655_out.puts(field.to_s)
    end
  end
end
f041_out.close
f655_out.close

### Step 2: Produce reports with the following from OCLC per row:
### OCLC number in 001
### 655 field

### OCLC numbers in 001
### 041 field

### Per 035$z, output 035$a and 035$z
oclc_f041_out = File.open("#{output_dir}/oclc_041_fields.tsv", 'w')
oclc_f655_out = File.open("#{output_dir}/oclc_655_fields.tsv", 'w')
oclc_f035z_out = File.open("#{output_dir}/oclc_035a_to_035z.tsv", 'w')
oclc_f041_out.puts("oclc\tfield")
oclc_f655_out.puts("oclc\tfield")
oclc_f035z_out.puts("oclc\txref")
Dir.glob("#{input_dir}/pul_oclc/metacoll*.mrc").each do |file|
  puts File.basename(file)
  reader = MARC::Reader.new(file)
  reader.each do |record|
    next unless wanted_oclc_record?(record)

    oclc_num = oclc_normalize(oclc: record['001'].value, input_prefix: false, output_prefix: false)

    record = delete_unwanted_fields(record)
    record.fields('041').each do |field|
      oclc_f041_out.write("#{oclc_num}\t")
      oclc_f041_out.puts(field.to_s)
    end
    record.fields('655').each do |field|
      oclc_f655_out.write("#{oclc_num}\t")
      oclc_f655_out.puts(field.to_s)
    end
    record.fields('035').each do |field|
      field.subfields.each do |subfield|
        next unless subfield.code == 'z'

        xref = oclc_normalize(oclc: subfield.value, input_prefix: false, output_prefix: false)
        oclc_f035z_out.write("#{oclc_num}\t")
        oclc_f035z_out.puts(xref)
      end
    end
  end
end
oclc_f041_out.close
oclc_f655_out.close
oclc_f035z_out.close

### Step 3: Create a mapping of xref to definitive OCLC number
xref_to_oclc = {}
File.open("#{input_dir}/oclc_035a_to_035z.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    oclc_num = parts[0]
    xref = parts[1]
    xref_to_oclc[xref] = oclc_num
  end
end

### Step 4: Load in all definitive OCLC numbers from OCLC
oclc_holdings = Set.new
File.open("#{output_dir}/oclc_041_fields.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    oclc_num = parts[0]
    oclc_holdings << oclc_num
  end
end
File.open("#{output_dir}/oclc_655_fields.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    oclc_num = parts[0]
    oclc_holdings << oclc_num
  end
end

### Step 5: Load in Alma records: skip any records not held in OCLC
###   MMS ID is the key, have 655 in one value, 041 in another, and definitive OCLC numbers in another
alma_records = {}
File.open("#{output_dir}/alma_041_fields.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    oclc_nums = Set.new(parts[1].split('|'))
    field = parts[2]
    xrefs = Set.new(oclc_nums.map { |num| xref_to_oclc[num] }).delete(nil)
    real_oclc_nums = ((oclc_nums & oclc_holdings) + xrefs).uniq
    next unless real_oclc_nums.size.positive?

    alma_records[mms_id] ||= {}
    alma_records[mms_id][:oclcs] ||= real_oclc_nums
    alma_records[mms_id][:f655] ||= []
    alma_records[mms_id][:f041] ||= []
    alma_records[mms_id][:f041] << field
  end
end
File.open("#{output_dir}/alma_655_fields.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    oclc_nums = Set.new(parts[1].split('|'))
    field = parts[2]
    xrefs = Set.new(oclc_nums.map { |num| xref_to_oclc[num] }).delete(nil)
    real_oclc_nums = ((oclc_nums & oclc_holdings) + xrefs).uniq
    next unless real_oclc_nums.size.positive?

    alma_records[mms_id] ||= {}
    alma_records[mms_id][:oclcs] ||= real_oclc_nums
    alma_records[mms_id][:f655] ||= []
    alma_records[mms_id][:f041] ||= []
    alma_records[mms_id][:f655] << field
  end
end

### Load in OCLC records, include 655 and 041 values
oclc_records = {}
File.open("#{output_dir}/oclc_041_fields.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    oclc_num = parts[0]
    oclc_records[oclc_num] ||= {}
    oclc_records[oclc_num][:f655] ||= []
    oclc_records[oclc_num][:f041] ||= []
    oclc_records[oclc_num][:f041] << parts[1]
  end
end
File.open("#{output_dir}/oclc_655_fields.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    oclc_num = parts[0]
    oclc_records[oclc_num] ||= {}
    oclc_records[oclc_num][:f655] ||= []
    oclc_records[oclc_num][:f041] ||= []
    oclc_records[oclc_num][:f655] << parts[1]
  end
end

### Output the unique OCLC numbers associated with each MMS ID
File.open("#{output_dir}/mms_id_to_oclc_nums_datasync.tsv", 'w') do |output|
  output.puts("MMS ID\tOCLC Numbers")
  alma_records.each do |mms_id, info|
    output.write("#{mms_id}\t")
    output.puts(info[:oclcs].join('|'))
  end
end

### Output the new 655 fields that would be added
stub = 'new_655_datasync'
fnum = 0
rec_num = 0
output = nil
alma_records.each do |mms_id, alma_info|
  oclc_info = {}
  alma_info[:oclcs].each do |oclc_num|
    oclc_info[oclc_num] = oclc_records[oclc_num] if oclc_records[oclc_num]
  end
  next if oclc_info.empty?

  if (rec_num % 100_000).zero?
    fnum += 1
    output&.close
    output = File.open("#{output_dir}/#{stub}_#{fnum}.tsv", 'w')
    output.puts("MMS ID\tNew 655 Field")
  end
  oclc_f655 = oclc_info.values.map { |info| info[:f655] }.flatten.uniq
  new_fields = oclc_f655 - alma_info[:f655]
  new_fields.each do |field|
    output.write("#{mms_id}\t")
    output.puts(field)
  end
  rec_num += 1
end
output.close

### Output a comparison of 041 fields
###   One column for MMS ID, one for system that has the 041 field, one for the field
output = File.open("#{output_dir}/041_comparison_datasync.tsv", 'w')
output.puts("MMS ID\tSystem\tField")
alma_records.each do |mms_id, alma_info|
  oclc_info = {}
  alma_info[:oclcs].each do |oclc_num|
    oclc_info[oclc_num] = oclc_records[oclc_num] if oclc_records[oclc_num]
  end
  next if oclc_info.empty?

  alma_f041 = alma_info[:f041].uniq
  oclc_f041 = oclc_info.map { |_num, info| info[:f041] }.flatten.uniq
  next unless (alma_f041 & oclc_f041).size != alma_f041.size

  alma_info[:f041].each do |field|
    output.write("#{mms_id}\t")
    output.write("alma\t")
    output.puts(field)
  end
  oclc_info.each_value do |info|
    info[:f041].each do |field|
      output.write("#{mms_id}\t")
      output.write("oclc\t")
      output.puts(field)
    end
  end
end
output.close
