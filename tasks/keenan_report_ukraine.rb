# frozen_string_literal: true

### Ideal set of records: items from all partners published in the last 5 years
###   with a language of Russian or Ukrainian
### Requirements:
###   Monographs
###   Primary language of item is Russian or Ukrainian [keep separate sheets]
###   Publication date after 2010
###   Include everything including unique items

### Preferred order of institutions for bibliographic data:
###   Princeton
###   Columbia
###   Harvard
###   NYPL

### For PUL items, include library/location code
require_relative './../lib/lsp-data'

def title_from_record(record)
  f245 = record['245']
  return nil unless f245

  title_string = ''.dup
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
    %w[0 6 e]
  else
    %w[0 6 j]
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
    target_field = select_264(f264)
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

def select_264(f264)
  f264.min_by(&:indicator2)
end

def info_from_record(record)
  hash = {}
  hash[:language] = record['008']&.value[35..37]
  hash[:pub_info] = publisher_info_from_record(record)
  hash[:f008_date1] = record['008']&.value[7..10]
  hash[:title] = title_from_record(record)
  hash[:author] = author_from_record(record)
  hash[:call_num] = call_num_from_bib_field(record: record,
                                     field_tag: '050').first&.full_call_num
  hash[:standard_nums] = standard_nums(record: record)
  hash
end

def cgds_from_scsb_record(record)
  record.fields('876').map { |field| field['x'] }.uniq
end

def cgd_for_pul_location(location)
  if %w[pa gp qk pf pv].include?(location)
    'Shared'
  else
    'Private'
  end
end

def cgds_from_pul_record(record)
  f852 = record.fields('852').select { |field| field['8'] =~ /^22/ }
  locations = f852.map { |field| field['c'] }.uniq
  locations.map { |location| cgd_for_pul_location(location) }.uniq
end

recap_locations = %w[
  arch$pw
  eastasian$pl
  eastasian$ql
  engineer$pt
  firestone$pb
  firestone$pf
  lewis$pn
  lewis$ps
  marquand$pj
  marquand$pv
  marquand$pz
  mendel$pk
  mendel$qk
  mudd$ph
  mudd$phr
  rare$xc
  rare$xcr
  rare$xg
  rare$xgr
  rare$xm
  rare$xmr
  rare$xn
  rare$xp
  rare$xr
  rare$xrr
  rare$xw
  rare$xx
  recap$gp
  recap$jq
  recap$pa
  recap$pe
  recap$pq
  recap$qv
  stokes$pm
]

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Parse records from most recent full dump to find:
###   Unsuppressed bibs
###   Position 7 of the leader is `m` for monographs
###   Date1 of 008 is 2010 or later [positions 7-10]
###   Holding is in a ReCAP location
###   Language of 008 is `ukr` or `rus` [positions 35-37]
### Add match key to the records prior to exporting the record
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_ukraine_pul_bibs.marcxml")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd'
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    f852 = record.fields('852').select { |field| field['8'] =~ /^22/ }
    locations = f852.map { |field| "#{field['b']}$#{field['c']}" }.uniq
    next unless (recap_locations & locations).size.positive?

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
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
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_ukraine_cul_bibs.marcxml")
Dir.glob("#{input_dir}/partners/cul/CUL_20250421_095200/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
Dir.glob("#{input_dir}/partners/cul/CUL_20250415_070000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### HL:
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_ukraine_hl_bibs.marcxml")
Dir.glob("#{input_dir}/partners/hl/HL_20250421_091500/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
Dir.glob("#{input_dir}/partners/hl/HL_20250415_230000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### NYPL:
writer = MARC::XMLWriter.new("#{output_dir}/keenan_report_ukraine_nypl_bibs.marcxml")
Dir.glob("#{input_dir}/partners/nypl/NYPL_20250415_150000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
Dir.glob("#{input_dir}/partners/cul/NYPL_20250421_101000/*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless record.leader[7] == 'm'
    next unless record['008'] && %w[ukr rus].include?(record['008'].value[35..37])

    date1 = record['008'].value[7..10].to_i
    next unless date1 > 2009

    match_key = LspData.get_match_key(record)
    record = field_delete_by_tags(record: record, tags: %w[grk])
    new_field = MARC::DataField.new('grd', ' ', ' ', MARC::Subfield.new('a', match_key))
    record.append(new_field)
    writer.write(record)
  end
end
writer.close

### Step 3: perform match key overlap analysis;
###   Match key is the key; separate symbols in the values for PUL, NYPL, HL, and CUL bib IDs
###   Also get bib info for the bibs for running a report
match_key_to_bibs = {}
bib_info = { pul: {}, cul: {}, hl: {}, nypl: {} } # Bib info for the matching bibs, broken down by institution
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_ukraine_cul_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grd']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:cul] << id
  bib_info[:cul][id] = record
end
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_ukraine_pul_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grd']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:pul] << id
  bib_info[:pul][id] = record
end
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_ukraine_nypl_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grd']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:nypl] << id
  bib_info[:nypl][id] = record
end
reader = MARC::XMLReader.new("#{output_dir}/keenan_report_ukraine_hl_bibs.marcxml", parser: 'magic')
reader.each do |record|
  id = record['001'].value
  match_key = record['grd']['a']
  match_key_to_bibs[match_key] ||= {}
  match_key_to_bibs[match_key][:cul] ||= []
  match_key_to_bibs[match_key][:pul] ||= []
  match_key_to_bibs[match_key][:nypl] ||= []
  match_key_to_bibs[match_key][:hl] ||= []
  match_key_to_bibs[match_key][:hl] << id
  bib_info[:hl][id] = record
end

### Step 4: Write out report; go match key by match key
ukrainian_output = File.open("#{output_dir}/keenan_report_ukrainian.tsv", 'w')
russian_output = File.open("#{output_dir}/keenan_report_russian.tsv", 'w')
ukrainian_output.puts("GoldRush Key\tLanguage\tPlace of Publication\tPublisher\tDate of Publication\tDate From 008\tTitle\tAuthor\tLC Call Number\tISBNs\tISSNs\tLCCNs\tOCLC Numbers\tPUL IDs\tPUL CGDs\tCUL IDs\tCUL CGDs\tHL IDs\tHL CGDs\tNYPL IDs\tNYPL CGDs\tInstitution of Cataloging Information\tSource of Cataloging Information")
russian_output.puts("GoldRush Key\tLanguage\tPlace of Publication\tPublisher\tDate of Publication\tDate From 008\tTitle\tAuthor\tLC Call Number\tISBNs\tISSNs\tLCCNs\tOCLC Numbers\tPUL IDs\tPUL CGDs\tCUL IDs\tCUL CGDs\tHL IDs\tHL CGDs\tNYPL IDs\tNYPL CGDs\tInstitution of Cataloging Information\tSource of Cataloging Information")
match_key_to_bibs.each do |match_key, institutions|
  cat_source_bib = nil
  cat_source_institution = nil
  if institutions[:pul].size.positive?
    bib_id = institutions[:pul].first
    cat_source_institution = 'PUL'
    cat_source_bib = bib_info[:pul][bib_id]
  elsif institutions[:cul].size.positive?
    bib_id = institutions[:cul].first
    cat_source_institution = 'CUL'
    cat_source_bib = bib_info[:cul][bib_id]
  elsif institutions[:hl].size.positive?
    bib_id = institutions[:hl].first
    cat_source_institution = 'HL'
    cat_source_bib = bib_info[:hl][bib_id]
  else
    bib_id = institutions[:nypl].first
    cat_source_institution = 'NYPL'
    cat_source_bib = bib_info[:nypl][bib_id]
  end
  cat_info = info_from_record(cat_source_bib)
  pul_ids = institutions[:pul]
  pul_cgds = []
  pul_ids.each do |id|
    record = bib_info[:pul][id]
    pul_cgds += cgds_from_pul_record(record)
  end
  cul_ids = institutions[:cul]
  cul_cgds = []
  cul_ids.each do |id|
    record = bib_info[:cul][id]
    cul_cgds += cgds_from_scsb_record(record)
  end
  hl_ids = institutions[:hl]
  hl_cgds = []
  hl_ids.each do |id|
    record = bib_info[:hl][id]
    hl_cgds += cgds_from_scsb_record(record)
  end
  nypl_ids = institutions[:nypl]
  nypl_cgds = []
  nypl_ids.each do |id|
    record = bib_info[:nypl][id]
    nypl_cgds += cgds_from_scsb_record(record)
  end
  if cat_info[:language] == 'ukr'
    ukrainian_output.write("#{match_key}\t")
    ukrainian_output.write("#{cat_info[:language]}\t")
    ukrainian_output.write("#{cat_info[:pub_info][:pub_place]}\t")
    ukrainian_output.write("#{cat_info[:pub_info][:pub_name]}\t")
    ukrainian_output.write("#{cat_info[:pub_info][:pub_date]}\t")
    ukrainian_output.write("#{cat_info[:f008_date1]}\t")
    ukrainian_output.write("#{cat_info[:title]}\t")
    ukrainian_output.write("#{cat_info[:author]}\t")
    ukrainian_output.write("#{cat_info[:call_num]}\t")
    ukrainian_output.write("#{cat_info[:standard_nums][:isbn].join(' | ')}\t")
    ukrainian_output.write("#{cat_info[:standard_nums][:issn].join(' | ')}\t")
    ukrainian_output.write("#{cat_info[:standard_nums][:lccn].join(' | ')}\t")
    ukrainian_output.write("#{cat_info[:standard_nums][:oclc].join(' | ')}\t")
    ukrainian_output.write("#{pul_ids.join(' | ')}\t")
    ukrainian_output.write("#{pul_cgds.join(' | ')}\t")
    ukrainian_output.write("#{cul_ids.join(' | ')}\t")
    ukrainian_output.write("#{cul_cgds.join(' | ')}\t")
    ukrainian_output.write("#{hl_ids.join(' | ')}\t")
    ukrainian_output.write("#{hl_cgds.join(' | ')}\t")
    ukrainian_output.write("#{nypl_ids.join(' | ')}\t")
    ukrainian_output.write("#{nypl_cgds.join(' | ')}\t")
    ukrainian_output.write("#{cat_source_institution}\t")
    ukrainian_output.puts(cat_source_bib['001'].value)
  else
    russian_output.write("#{match_key}\t")
    russian_output.write("#{cat_info[:language]}\t")
    russian_output.write("#{cat_info[:pub_info][:pub_place]}\t")
    russian_output.write("#{cat_info[:pub_info][:pub_name]}\t")
    russian_output.write("#{cat_info[:pub_info][:pub_date]}\t")
    russian_output.write("#{cat_info[:f008_date1]}\t")
    russian_output.write("#{cat_info[:title]}\t")
    russian_output.write("#{cat_info[:author]}\t")
    russian_output.write("#{cat_info[:call_num]}\t")
    russian_output.write("#{cat_info[:standard_nums][:isbn].join(' | ')}\t")
    russian_output.write("#{cat_info[:standard_nums][:issn].join(' | ')}\t")
    russian_output.write("#{cat_info[:standard_nums][:lccn].join(' | ')}\t")
    russian_output.write("#{cat_info[:standard_nums][:oclc].join(' | ')}\t")
    russian_output.write("#{pul_ids.join(' | ')}\t")
    russian_output.write("#{pul_cgds.join(' | ')}\t")
    russian_output.write("#{cul_ids.join(' | ')}\t")
    russian_output.write("#{cul_cgds.join(' | ')}\t")
    russian_output.write("#{hl_ids.join(' | ')}\t")
    russian_output.write("#{hl_cgds.join(' | ')}\t")
    russian_output.write("#{nypl_ids.join(' | ')}\t")
    russian_output.write("#{nypl_cgds.join(' | ')}\t")
    russian_output.write("#{cat_source_institution}\t")
    russian_output.puts(cat_source_bib['001'].value)
  end
end
ukrainian_output.close
russian_output.close
