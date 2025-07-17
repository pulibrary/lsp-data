# frozen_string_literal: true

require_relative './../lib/lsp-data'
def delete_unwanted_fields(record)
  ind2_tags = (600..654).to_a + (656..699).to_a
  record.fields.delete_if { |f| ind2_tags.include?(f.tag.to_i) && f.indicator2 != '0' }
  record.fields.delete_if { |f| f.tag.to_i.between?(600, 699) && f['6'] }
  record
end

def wanted_alma_record?(record)
  oclc_nums = oclcs(record: record)
  cz = record.fields.any? { |f| f.tag == '035' && f['a'] =~ /^\(CKB\)/ }
  oclc_nums.size == 1 && record.leader[5] != 'd' && cz == false
end

def process_alma_record(record)
  record = delete_unwanted_fields(record)
  record.fields('600'..'699').each do |field|
    field.subfields.delete_if { |s| s.code == '0' }
  end
  record.fields.delete_if { |f| f.tag.to_i.between?(600, 699) && %w[NjP PUL].include?(f['5']) }
  record
end

post_subjects = {}
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
Dir.glob("#{input_dir}/pul_oclc/metacoll*.mrc").each do |file|
  puts File.basename(file)
  reader = MARC::Reader.new(file)
  reader.each do |record|
    oclc_num = oclc_normalize(oclc: record['001'].value, input_prefix: false, output_prefix: false)
    record = delete_unwanted_fields(record)
    record.fields('600'..'699').each do |field|
      field.subfields.delete_if { |s| s.code == '0' }
    end
    post_subjects[oclc_num] = Set.new(record.fields('600'..'699').map(&:to_s))
  end
end

changed_subjects = {}
mms_to_oclc = {}
### 6xx fields with subfield 5 would be untouched, so remove them from the comparison
### Ignore records with a (CKB) 035 field
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_alma_record?(record)

    oclc_num = oclcs(record: record).first
    post = post_subjects[oclc_num]
    next unless post

    mms_id = record['001'].value
    mms_to_oclc[mms_id] = oclc_num
    record = process_alma_record(record)

    pre = Set.new(record.fields('600'..'699').map(&:to_s))
    changed_subjects[mms_id] = {
      add: post - pre,
      remove: pre - post
    }
  end
end

unchanged_mms = []
processed_mms = 0
fnum = 0
file_stub = '6xx_comparison_june_2025'
output = nil
changed_subjects.each do |mms_id, subjects|
  if (subjects[:add].size + subjects[:remove].size).zero?
    unchanged_mms << mms_id
  else
    if (processed_mms % 100_000).zero?
      output&.close
      fnum += 1
      output = File.open("#{output_dir}/#{file_stub}_#{fnum}.tsv", 'w')
      output.puts("MMS ID\tOCLC Number\tField Tag\tField Added Or Removed\tAction")
    end
    oclc_num = mms_to_oclc[mms_id]
    subjects[:add].each do |subject|
      output.write("#{mms_id}\t#{oclc_num}\t")
      field_tag = subject[0..2]
      output.write("#{field_tag}\t#{subject}\t")
      output.puts('add')
    end
    subjects[:remove].each do |subject|
      output.write("#{mms_id}\t#{oclc_num}\t")
      field_tag = subject[0..2]
      output.write("#{field_tag}\t#{subject}\t")
      output.puts('remove')
    end
    processed_mms += 1
  end
end
output.close

file_stub = '6xx_comparison_mms_ids_no_change'
fnum = 1
unchanged_mms.each_slice(1_000_000) do |subset|
  File.open("#{output_dir}/#{file_stub}_#{fnum}.txt", 'w') do |mms_out|
    mms_out.puts('MMS ID')
    subset.each { |id| mms_out.puts(id) }
  end
  fnum += 1
end
