# frozen_string_literal: true

### Ideal set of records: items from all partners published since 2019
###   with a language of Russian and publication place of Moscow or St. Petersburg (also spelled out)
### Requirements:
###   Monographs
###   Primary language of item is Russian
###   Publication date 2019-2025
###   all PUL locations, all ReCAP partners, and ebooks

### Preferred order of institutions for bibliographic data:
###   Princeton Print
###   Princeton Electronic
###   Columbia
###   Harvard
###   NYPL

### For PUL items, include library/location code
require_relative './../lib/lsp-data'

def title_from_record(record)
  f245 = record['245']
  return nil unless f245

  ''.dup
  targets = f245.subfields.reject { |subfield| subfield.code == '6' }
  c_index = targets.index { |subfield| subfield.code == 'c' }
  c_index ||= 0
  subf_values = targets[0..c_index - 1].map(&:value)
  title_string = subf_values.join(' ')
  scrub_string(title_string)
end

def auth_subfields_to_skip(field_tag)
  case field_tag
  when '100', '110'
    %w[0 1 4 6 e]
  else
    %w[0 1 4 6 j]
  end
end

def scrub_string(string)
  return string if string.nil?

  new_string = string.dup
  new_string.strip!
  new_string[-1] = '' if new_string[-1] =~ %r{[.,:/=]}
  new_string.strip!
  new_string.gsub(/(\s){2, }/, '\1')
end

def author_from_record(record)
  auth_fields = record.fields(%w[100 110 111])
  return nil if auth_fields.empty?

  auth_field = auth_fields.first
  auth_tag = auth_field.tag
  subf_to_skip = auth_subfields_to_skip(auth_tag)
  targets = auth_field.subfields.reject do |subfield|
    subf_to_skip.include?(subfield.code)
  end
  author = targets.map(&:value).join(' ')
  scrub_string(author)
end

def publisher_info_from_record(record)
  f260 = record['260']
  f264 = record.fields('264')
  return publisher_info(f260) if f260

  unless f264.empty?
    target_field = select_f264(f264)
    return publisher_info(target_field)
  end
  { pub_place: nil, pub_name: nil, pub_date: nil }
end

def publisher_info(field)
  pub_place = scrub_string(field['a'])
  pub_name = scrub_string(field['b'])
  pub_date = scrub_string(field['c'])
  { pub_place: pub_place, pub_name: pub_name, pub_date: pub_date }
end

def select_f264(f264)
  f264.min_by(&:indicator2)
end

def info_from_record(record)
  {
    language: record['008']&.value&.[](35..37),
    pub_info: publisher_info_from_record(record),
    f008_date1: record['008']&.value&.[](7..10),
    title: title_from_record(record),
    author: author_from_record(record),
    call_num: call_num_from_bib_field(record: record,
                                      field_tag: '050').first&.full_call_num,
    standard_nums: standard_nums(record: record)
  }
end

def cgds_from_scsb_record(record)
  record.fields('876').map { |field| field['x'] }.uniq
end

def cgd_for_pul_location(location)
  if %w[pa gp qk pf pv].include?(location[0..1])
    'Shared'
  else
    'Private'
  end
end

def cgds_from_pul_record(record)
  f852 = record.fields('852').select { |field| field['8'] =~ /^22/ }
  loc_combos = f852.map { |field| "#{field['b']}$#{field['c']}" }
  recap = loc_combos.select { |combo| recap_locations.include?(combo) }
  recap.map { |combo| cgd_for_pul_location(combo.gsub(/^.*\$(.*)$/, '\1')) }
end

def recap_locations
  %w[
    arch$pw eastasian$pl eastasian$ql engineer$pt
    firestone$pb firestone$pf lewis$pn lewis$ps
    marquand$pj marquand$pv marquand$pz
    mendel$pk mendel$qk mudd$ph mudd$phr
    rare$xc rare$xcr rare$xg rare$xgr rare$xm rare$xmr
    rare$xn rare$xp rare$xr rare$xrr rare$xw rare$xx
    recap$gp recap$jq recap$pa recap$pe recap$pq recap$qv
    stokes$pm
  ]
end

def wanted_leader?(record)
  record.leader[5] != 'd' &&
    record.leader[7] == 'm'
end

def wanted_record?(record)
  pub_place = publisher_info_from_record(record)[:pub_place]
  wanted_leader?(record) &&
    record['008'] && record['008'].value[35..37] == 'rus' &&
    record['008'].value[7..10].to_i > 2018 &&
    pub_place =~ /^Moscow|^St\. Petersburg|^Saint Petersburg|^Sankt-Peterburg|^Moskva/
end

def pul_locations(record)
  record.fields('852').select { |f| f['8'] =~ /^22[0-9]+6421$/ }
        .map { |f| "#{f['b']}$#{f['c']}" }
end

def pul_electronic?(record)
  record.fields('951').any? { |f| f['0'] =~ /^53[0-9]+$/ } &&
    record.fields('852').select { |f| f['8'] =~ /^22[0-9]+6421$/ }.empty?
end

def cat_source_institution(institutions)
  return :pul_print if institutions[:pul_print].size.positive?
  return :pul_electronic if institutions[:pul_electronic].size.positive?
  return :cul if institutions[:cul].size.positive?
  return :hl if institutions[:hl].size.positive?

  :nypl
end

def total_bibs(institutions)
  institutions.values.map(&:size).sum
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Parse records from most recent full dump to find:
###   Unsuppressed bibs
###   Position 7 of the leader is `m` for monographs
###   Date1 of 008 is 2019 or later [positions 7-10]
###   Language of 008 is `rus` [positions 35-37]
###   Place of publication is Moscow, St. Petersburg, or Saint Petersburg
### Add match key to the records prior to writing them out
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_russian_pul_bibs.marcxml")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### Step 2: Parse partner records from most recent full dumps
###   (including Private) to find:
###   Position 7 of the leader is `m` for monographs
###   Date1 of 008 is 2010 or later [positions 7-10]
###   Language of 008 is `ukr` or `rus` [positions 35-37]
### Add match key to the records prior to exporting the record

### CUL:
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_russian_cul_bibs.marcxml")
Dir.glob("#{input_dir}/partners/cul/CUL_20250801_070000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
Dir.glob("#{input_dir}/partners/cul/CUL_20250808_100400/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### HL:
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_russian_hl_bibs.marcxml")
Dir.glob("#{input_dir}/partners/hl/HL_20250801_230000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
Dir.glob("#{input_dir}/partners/hl/HL_20250808_093100/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### NYPL:
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_russian_nypl_bibs.marcxml")
Dir.glob("#{input_dir}/partners/nypl/NYPL_20250801_150000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
Dir.glob("#{input_dir}/partners/cul/NYPL_20250808_102300/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless wanted_record?(record)

    match_key = MarcMatchKey::Key.new(record).key[0..-2] # Match electronic books to print
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grk', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### Step 3: perform match key overlap analysis;
###   Match key is the key; separate symbols in the values for PUL, NYPL, HL, and CUL bib IDs
###   Also get bib info for the bibs for running a report
match_key_to_bibs = {}
# Bib info for the matching bibs, broken down by institution
bib_info = { pul_print: {}, pul_electronic: {}, cul: {}, hl: {}, nypl: {} }
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_russian_cul_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grk']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul_print] ||= []
  match_key_to_bibs[match_key][:pul_electronic] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:cul] << id
  bib_info[:cul][id] = record
end
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_russian_pul_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grk']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul_print] ||= []
  match_key_to_bibs[match_key][:pul_electronic] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  if pul_electronic?(record)
    match_key_to_bibs[match_key][:pul_electronic] << id
    bib_info[:pul_electronic][id] = record
  else
    match_key_to_bibs[match_key][:pul_print] << id
    bib_info[:pul_print][id] = record
  end
end
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_russian_nypl_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grk']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul_print] ||= []
  match_key_to_bibs[match_key][:pul_electronic] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:nypl] << id
  bib_info[:nypl][id] = record
end
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_russian_hl_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grk']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul_print] ||= []
  match_key_to_bibs[match_key][:pul_electronic] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:hl] << id
  bib_info[:hl][id] = record
end

### Step 4: Write out report; go match key by match key
output = File.open("#{output_dir}/keenan_report_russian_08-2025.tsv", 'w')
output.write("GoldRush Key\tLanguage\tPlace of Publication\tPublisher\tDate of Publication\t")
output.write("Date From 008\tTitle\tAuthor\tLC Call Number\tISBNs\tISSNs\tLCCNs\tOCLC Numbers\t")
output.write("Total Count of IDs\tPUL Electronic IDs\tPUL Print IDs\tPUL Print Locations\tPUL CGDs\t")
output.write("CUL IDs\tCUL CGDs\tHL IDs\tHL CGDs\tNYPL IDs\tNYPL CGDs\t")
output.puts("Institution of Cataloging Information\tSource of Cataloging Information")
match_key_to_bibs.each do |match_key, institutions|
  cat_source_institution = cat_source_institution(institutions)
  cat_source_id = institutions[cat_source_institution].first
  cat_source_bib = bib_info[cat_source_institution][cat_source_id]
  cat_info = info_from_record(cat_source_bib)
  all_pul_locations = institutions[:pul_print].map { |id| pul_locations(bib_info[:pul_print][id]) }.uniq
  pul_cgds = institutions[:pul_print].map { |id| cgds_from_pul_record(bib_info[:pul_print][id]) }.uniq
  cul_cgds = institutions[:cul].map { |id| cgds_from_scsb_record(bib_info[:cul][id]) }.uniq
  hl_cgds = institutions[:hl].map { |id| cgds_from_scsb_record(bib_info[:hl][id]) }.uniq
  nypl_cgds = institutions[:nypl].map { |id| cgds_from_scsb_record(bib_info[:nypl][id]) }.uniq
  output.write("#{match_key}\t#{cat_info[:language]}\t")
  output.write("#{cat_info[:pub_info][:pub_place]}\t#{cat_info[:pub_info][:pub_name]}\t")
  output.write("#{cat_info[:pub_info][:pub_date]}\t#{cat_info[:f008_date1]}\t")
  output.write("#{cat_info[:title]}\t#{cat_info[:author]}\t#{cat_info[:call_num]}\t")
  output.write("#{cat_info[:standard_nums][:isbn].join(' | ')}\t#{cat_info[:standard_nums][:issn].join(' | ')}\t")
  output.write("#{cat_info[:standard_nums][:lccn].join(' | ')}\t#{cat_info[:standard_nums][:oclc].join(' | ')}\t")
  output.write("#{total_bibs(institutions)}\t")
  output.write("#{institutions[:pul_electronic].join(' | ')}\t#{institutions[:pul_print].join(' | ')}\t")
  output.write("#{all_pul_locations.join(' | ')}\t#{pul_cgds.join(' | ')}\t")
  output.write("#{institutions[:cul].join(' | ')}\t#{cul_cgds.join(' | ')}\t")
  output.write("#{institutions[:hl].join(' | ')}\t#{hl_cgds.join(' | ')}\t")
  output.write("#{institutions[:nypl].join(' | ')}\t#{nypl_cgds.join(' | ')}\t")
  output.puts("#{cat_source_institution}\t#{cat_source_bib['001'].value}")
end
output.close
