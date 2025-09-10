# frozen_string_literal: true

### Find overlap between Firestone Stacks and the rest of PUL print, along with
###   ReCAP partner SCSB holdings (only shared items) and
###   ReCAP partner OCLC holdings; include Yale

require_relative './../lib/lsp-data'

def firestone_holding?(field)
  field['8'] =~ /^22[0-9]+6421$/ &&
    field['b'] == 'firestone' &&
    field['c'] == 'stacks'
end

def firestone_record?(record)
  holdings = record.fields('852').select do |field|
    firestone_holding?(field)
  end
  holding_ids = holdings.map { |field| field['8'] }
  record.fields('876').any? do |field|
    holding_ids.include?(field['0']) &&
      field['p'].to_s.strip != ''
  end
end

def non_firestone_record?(record)
  holdings = record.fields('852').select do |field|
    field['8'] =~ /^22[0-9]+6421$/ && !firestone_holding?(field)
  end
  holding_ids = holdings.map { |field| field['8'] }
  record.fields('876').any? do |field|
    holding_ids.include?(field['0']) &&
      field['p'].to_s.strip != ''
  end
end

def eligible_record?(record)
  record.leader[7] == 'm'
end

def partners_output_match_keys(input:, output:, file_type: nil)
  reader = file_type == 'xml' ? MARC::XMLReader.new(input, parser: 'magic') : MARC::Reader.new(input)
  reader.each do |record|
    next unless eligible_record?(record)

    match_key = MarcMatchKey::Key.new(record).key
    id = record['001'].value
    output.puts("#{id}\t#{match_key}")
  end
end

def add_matches_from_file(file:, matches:, inst_symbol:)
  File.open(file, 'r') do |input|
    while (line = input.gets)
      parts = line.chomp.split("\t")
      matches[parts[1]] ||= { nof_pul: [], scsbcul: [], scsbhl: [], scsbnypl: [],
                              f_pul: [], oclccul: [], oclchl: [], oclcnypl: [],
                              lsfyul: [], oclcyul: [] }
      matches[parts[1]][inst_symbol] << parts[0]
    end
  end
  matches
end

def add_other_matches_from_file(file:, matches:, inst_symbol:)
  File.open(file, 'r') do |input|
    while (line = input.gets)
      parts = line.chomp.split("\t")
      key = parts[1]
      next unless matches[key]

      matches[key][inst_symbol] << parts[0]
    end
  end
  matches
end

def title_from_field(field)
  return scrub_string(field['a']) if field['a']

  targets = field.subfields.reject { |subfield| subfield.code == '6' }
  c_index = targets.index { |subfield| subfield.code == 'c' }
  c_index ||= -1
  title_string = targets[0..c_index].map(&:value).join(' ')
  scrub_string(title_string)
end

def title(record)
  f880_title_field = record.fields('880').find { |field| field['6'] && field['6'] =~ /^245/ }
  if f880_title_field
    title_from_field(f880_title_field)
  else
    title_field = record['245']
    title_from_field(title_field)
  end
end

def info_from_f008(record)
  f008 = record['008']
  { date1: f008&.value&.[](7..10), pub_place: f008&.value&.[](15..17) }
end

def publisher_info_from_field(field)
  pub_place = scrub_string(field['a'])
  pub_name = scrub_string(field['b'])
  pub_date = scrub_string(field['c'])
  { pub_place: pub_place, pub_name: pub_name, pub_date: pub_date }
end

def publisher_info(record)
  f260 = record['260']
  return publisher_info_from_field(f260) if f260

  f264 = record.fields('264').min_by(&:indicator2)
  if f264
    publisher_info_from_field(f264)
  else
    { pub_place: nil, pub_name: nil, pub_date: nil }
  end
end

def author_subfields_to_skip(field_tag)
  case field_tag
  when '100', '110'
    %w[0 1 6 4 e]
  else
    %w[0 1 6 4 j]
  end
end

def author(record)
  auth_field = record.fields(%w[100 110 111]).first
  return unless auth_field

  subf_to_skip = author_subfields_to_skip(auth_field.tag)
  author_string = auth_field.subfields.reject do |subfield|
    subf_to_skip.include?(subfield.code)
  end.map(&:value)
     .join(' ')
  scrub_string(author_string)
end

def imprint_fields(record)
  target_fields = record.fields('250'..'259')
  return [] if target_fields.empty?

  fields = []
  target_fields.each do |field|
    text = field.subfields.map(&:value).join(' ')
    fields << scrub_string(text)
  end
  fields
end

def scrub_string(string)
  return unless string

  new_string = string.dup.strip
  new_string[-1] = '' if new_string[-1] =~ %r{[.,:/=]}
  new_string.gsub!(/[\t\r\n]/, '')
  new_string.strip.gsub(/(\s){2, }/, '\1')
end

def info_for_record(record)
  {
    isbns: isbns(record),
    oclcs: oclcs(record: record),
    title: title(record),
    author: author(record),
    f008: info_from_f008(record),
    publisher_info: publisher_info(record),
    imprint_fields: imprint_fields(record)
  }
end

def add_report_headers(output)
  output.write("Match Key\tSource of Description\tAuthor\tTitle\t")
  output.write("008 Date\t008 Place of Publication\tISBNs\tOCLCs\t")
  output.write("Imprint Info\tPub Place\tPublisher\tPub Date\t")
  output.write("Firestone\tPUL Non-Firestone\tAll Partner Institutions\t")
  output.write("CUL ReCAP\tCUL OCLC\tHUL ReCAP\tHUL OCLC\tNYPL ReCAP\tNYPL OCLC\t")
  output.puts("Yale Remote\tYale OCLC")
end

def all_info(inst:, all_bib_info:)
  bib_info_id = inst[:f_pul].first
  bib_info = all_bib_info[bib_info_id]
  { bib_info_id: bib_info_id, bib_info: bib_info }
end

def write_bib_info(bib_info:, output:)
  output.write("#{bib_info[:author]}\t#{bib_info[:title]}\t")
  output.write("#{bib_info[:f008][:date1]}\t#{bib_info[:f008][:pub_place]}\t")
  output.write("#{bib_info[:isbns].join(' | ')}\t#{bib_info[:oclcs].join(' | ')}\t")
  write_imprint_publisher_info(bib_info: bib_info, output: output)
end

def write_imprint_publisher_info(bib_info:, output:)
  output.write("#{bib_info[:imprint_fields].join(' | ')}\t")
  output.write("#{bib_info[:publisher_info][:pub_place]}\t")
  output.write("#{bib_info[:publisher_info][:pub_name]}\t")
  output.write("#{bib_info[:publisher_info][:pub_date]}\t")
end

def partner_bib_format(inst)
  inst.transform_values { |ids| ids.join(' | ') }
end

def write_overlap_info(all_partners:, inst:, output:)
  formatted_partners = partner_bib_format(inst)
  output.write("#{formatted_partners[:f_pul]}\t#{formatted_partners[:nof_pul]}\t#{all_partners}\t")
  output.write("#{formatted_partners[:scsbcul]}\t#{formatted_partners[:oclccul]}\t")
  output.write("#{formatted_partners[:scsbhl]}\t#{formatted_partners[:oclchl]}\t")
  output.write("#{formatted_partners[:scsbnypl]}\t#{formatted_partners[:oclcnypl]}\t")
  output.puts("#{formatted_partners[:lsfyul]}\t#{formatted_partners[:oclcyul]}")
end

### Step 1: Make tab-delimited files of each institution's IDs with
###   the match key for further overlap analysis

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

puts('cul')
File.open("#{output_dir}/cul_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, file_type: 'xml')
  end
end

File.open("#{output_dir}/cul_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

puts('hl')
File.open("#{output_dir}/hl_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, file_type: 'xml')
  end
end

File.open("#{output_dir}/hl_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

puts('nypl')
File.open("#{output_dir}/nypl_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, file_type: 'xml')
  end
end

File.open("#{output_dir}/nypl_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

puts('yale')
File.open("#{output_dir}/yale_lsf_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/yale/remote/*.marcxml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, file_type: 'xml')
  end
end

File.open("#{output_dir}/yale_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/yale/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

### Step 2: Produce match keys for all PUL bibs with print inventory;
###   separate files for Firestone Stacks records
firestone = File.open("#{output_dir}/pul_firestone_match_keys.tsv", 'w')
non_firestone = File.open("#{output_dir}/pul_not_firestone_match_keys.tsv", 'w')
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless eligible_record?(record)
    next if record.leader[5] == 'd'

    match_key = MarcMatchKey::Key.new(record).key
    id = record['001'].value
    firestone.puts("#{id}\t#{match_key}") if firestone_record?(record)
    non_firestone.puts("#{id}\t#{match_key}") if non_firestone_record?(record)
  end
end
firestone.close
non_firestone.close

### Step 3: Perform overlap analysis; for each institution,
###   the match key is the key, bib IDs are the values
matches = {}
add_matches_from_file(file: "#{output_dir}/pul_firestone_match_keys.tsv", matches: matches, inst_symbol: :f_pul)
add_other_matches_from_file(file: "#{output_dir}/pul_recap_match_keys.tsv", matches: matches, inst_symbol: :nof_pul)
add_other_matches_from_file(file: "#{output_dir}/cul_oclc_match_keys.tsv", matches: matches, inst_symbol: :oclccul)
add_other_matches_from_file(file: "#{output_dir}/cul_scsb_match_keys.tsv", matches: matches, inst_symbol: :scsbcul)
add_other_matches_from_file(file: "#{output_dir}/hl_scsb_match_keys.tsv", matches: matches, inst_symbol: :scsbhl)
add_other_matches_from_file(file: "#{output_dir}/hl_oclc_match_keys.tsv", matches: matches, inst_symbol: :oclchl)
add_other_matches_from_file(file: "#{output_dir}/nypl_scsb_match_keys.tsv", matches: matches, inst_symbol: :scsbnypl)
add_other_matches_from_file(file: "#{output_dir}/nypl_oclc_match_keys.tsv", matches: matches, inst_symbol: :oclcnypl)
add_other_matches_from_file(file: "#{output_dir}/yale_lsf_match_keys.tsv", matches: matches, inst_symbol: :lsfyul)
add_other_matches_from_file(file: "#{output_dir}/yale_oclc_match_keys.tsv", matches: matches, inst_symbol: :oclcyul)

### Step 4: Remove OCLC matches from partners when there is a remote storage ID for the same institution
matches.each_value do |inst|
  inst[:oclccul].clear if inst[:scsbcul].size.positive?
  inst[:oclchl].clear if inst[:scsbhl].size.positive?
  inst[:oclcnypl].clear if inst[:scsbnypl].size.positive?
  inst[:oclcyul].clear if inst[:lsfyul].size.positive?
end

### Step 5: Gather bib info from the Firestone bibs
all_bib_info = {}
f_bib_ids = Set.new(matches.values.map { |inst| inst[:f_pul] }.flatten)
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    bib_id = record['001'].value
    all_bib_info[bib_id] = info_for_record(record) if f_bib_ids.include?(bib_id)
  end
end

### Step 6: Output the report; one line per match key
output = nil
processed = 0
fname = 'magier_firestone_overlap'
fnum = 1
matches.each do |key, inst|
  if (processed % 800_000).zero?
    output&.close
    output = File.open("#{output_dir}/#{fname}_#{fnum}.tsv", 'w')
    add_report_headers(output)
    fnum += 1
  end
  all_info = all_info(inst: inst, all_bib_info: all_bib_info)
  all_partners = inst.select { |_name, ids| ids.size.positive? }.keys
  all_partners.delete_if { |symbol| %i[f_pul nof_pul].include?(symbol) }
  all_partners = all_partners.map(&:to_s).join(' | ')
  output.write("#{key}\t")
  output.write("#{all_info[:bib_info_id]}\t")
  write_bib_info(bib_info: all_info[:bib_info], output: output)
  write_overlap_info(all_partners: all_partners, inst: inst, output: output)
  processed += 1
end
output.close
