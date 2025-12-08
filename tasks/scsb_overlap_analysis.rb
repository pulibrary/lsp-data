# frozen_string_literal: true

### An overlap analysis is run across ReCAP partners and PUL to find uniqueness
###   at each institution; focus on percentage of titles unique to each institution;
###   one analysis is only ReCAP shared and PUL shared, another is including OCLC holdings
### Ignore electronic marker for ReCAP shared
### Include electronic marker for broader analysis

require_relative './../lib/lsp-data'

def shared_recap_locations
  %w[recap$pa recap$gp mendel$qk firestone$pf marquand$pv]
end

def shared_recap_location?(library:, location:)
  shared_recap_locations.include?("#{library}$#{location}")
end

def partners_output_match_keys(input:, output:, type: 'xml')
  reader = if type == 'xml'
             MARC::XMLReader.new(input, parser: 'magic')
           else
             MARC::Reader.new(input, external_encoding: 'utf-8', invalid: :replace, replace: '')
           end
  reader.each do |record|
    match_key = MarcMatchKey::Key.new(record).key
    id = record['001'].value
    output.puts("#{id}\t#{match_key}")
  end
end

### Ignore final character of match key (electronic indicator) for SCSB report
def add_matches_from_file(file:, matches:, inst_symbol:)
  File.open(file, 'r') do |input|
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t") # MMS ID and Key
      key = File.basename(file) =~ /scsb/ ? parts[1][0..-2] : parts[1]
      matches[key][inst_symbol] ||= []
      matches[key][inst_symbol] << parts[0]
    end
  end
  matches
end

### Step 1: Make tab-delimited files of each institution's IDs with
###   the match key for further overlap analysis

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

File.open("#{output_dir}/cul_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

File.open("#{output_dir}/cul_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, type: 'marc')
  end
end

File.open("#{output_dir}/hl_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

File.open("#{output_dir}/hl_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, type: 'marc')
  end
end

File.open("#{output_dir}/nypl_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

File.open("#{output_dir}/nypl_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/oclc/metacoll*.mrc").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output, type: 'marc')
  end
end

### Step 2: Produce match keys for all PUL bibs;
###   make a separate file for only shared ReCAP
recap = File.open("#{output_dir}/pul_scsb_match_keys.tsv", 'w')
all = File.open("#{output_dir}/pul_all_match_keys.tsv", 'w')
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd'

    holdings = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
    next if holdings.empty?

    shared_locations = holdings.select do |field|
      shared_recap_location?(library: field['b'], location: field['c'])
    end
    holding_ids = shared_locations.map { |field| field['8'] }
    recap_items = record.fields('876').select do |field|
      holding_ids.include?(field['0'])
    end

    match_key = MarcMatchKey::Key.new(record).key
    id = record['001'].value
    recap.puts("#{id}\t#{match_key}") unless recap_items.empty?
    all.puts("#{id}\t#{match_key}")
  end
end
recap.close
all.close

### Step 3: Perform SCSB overlap analysis; for each institution,
###   the match key is the key, bib IDs are the values
scsb_matches = {}
add_matches_from_file(file: "#{output_dir}/pul_scsb_match_keys.tsv", matches: scsb_matches, inst_symbol: :scsbpul)
add_matches_from_file(file: "#{output_dir}/cul_scsb_match_keys.tsv", matches: scsb_matches, inst_symbol: :scsbcul)
add_matches_from_file(file: "#{output_dir}/hl_scsb_match_keys.tsv", matches: scsb_matches, inst_symbol: :scsbhl)
add_matches_from_file(file: "#{output_dir}/nypl_scsb_match_keys.tsv", matches: scsb_matches, inst_symbol: :scsbnypl)

pul_recap_unique = scsb_matches.select { |_key, sites| sites[:scsbpul] && sites.size == 1 }
cul_recap_unique = scsb_matches.select { |_key, sites| sites[:scsbcul] && sites.size == 1 }
nypl_recap_unique = scsb_matches.select { |_key, sites| sites[:scsbnypl] && sites.size == 1 }
hl_recap_unique = scsb_matches.select { |_key, sites| sites[:scsbhl] && sites.size == 1 }
pul_recap_all = scsb_matches.select { |_key, sites| sites[:scsbpul] }
cul_recap_all = scsb_matches.select { |_key, sites| sites[:scsbcul] }
nypl_recap_all = scsb_matches.select { |_key, sites| sites[:scsbnypl] }
hl_recap_all = scsb_matches.select { |_key, sites| sites[:scsbhl] }

File.open("#{output_dir}/scsb_shared_overlap_statistics.tsv", 'w') do |output|
  output.puts("Institution\tTotal Number of Match Keys\tUnique Match Keys")
  output.write("PUL\t")
  output.write("#{pul_recap_all.size}\t")
  output.puts(pul_recap_unique.size)
  output.write("CUL\t")
  output.write("#{cul_recap_all.size}\t")
  output.puts(cul_recap_unique.size)
  output.write("NYPL\t")
  output.write("#{nypl_recap_all.size}\t")
  output.puts(nypl_recap_unique.size)
  output.write("HL\t")
  output.write("#{hl_recap_all.size}\t")
  output.puts(hl_recap_unique.size)
end

### Step 4: Perform complete overlap analysis; for this one, format matters
scsb_matches.clear
all_matches = {}
add_matches_from_file(file: "#{output_dir}/pul_all_match_keys.tsv", matches: all_matches, inst_symbol: :allpul)
add_matches_from_file(file: "#{output_dir}/cul_scsb_match_keys.tsv", matches: all_matches, inst_symbol: :allcul)
add_matches_from_file(file: "#{output_dir}/hl_scsb_match_keys.tsv", matches: all_matches, inst_symbol: :allhl)
add_matches_from_file(file: "#{output_dir}/nypl_scsb_match_keys.tsv", matches: all_matches, inst_symbol: :allnypl)
add_matches_from_file(file: "#{output_dir}/cul_oclc_match_keys.tsv", matches: all_matches, inst_symbol: :allcul)
add_matches_from_file(file: "#{output_dir}/hl_oclc_match_keys.tsv", matches: all_matches, inst_symbol: :allhl)
add_matches_from_file(file: "#{output_dir}/nypl_oclc_match_keys.tsv", matches: all_matches, inst_symbol: :allnypl)

pul_all_unique = all_matches.select { |_key, sites| sites[:allpul] && sites.size == 1 }
cul_all_unique = all_matches.select { |_key, sites| sites[:allcul] && sites.size == 1 }
nypl_all_unique = all_matches.select { |_key, sites| sites[:allnypl] && sites.size == 1 }
hl_all_unique = all_matches.select { |_key, sites| sites[:allhl] && sites.size == 1 }
pul_all_all = all_matches.select { |_key, sites| sites[:allpul] }
cul_all_all = all_matches.select { |_key, sites| sites[:allcul] }
nypl_all_all = all_matches.select { |_key, sites| sites[:allnypl] }
hl_all_all = all_matches.select { |_key, sites| sites[:allhl] }

File.open("#{output_dir}/all_overlap_statistics.tsv", 'w') do |output|
  output.puts("Institution\tTotal Number of Match Keys\tUnique Match Keys")
  output.write("PUL\t")
  output.write("#{pul_all_all.size}\t")
  output.puts(pul_all_unique.size)
  output.write("CUL\t")
  output.write("#{cul_all_all.size}\t")
  output.puts(cul_all_unique.size)
  output.write("NYPL\t")
  output.write("#{nypl_all_all.size}\t")
  output.puts(nypl_all_unique.size)
  output.write("HL\t")
  output.write("#{hl_all_all.size}\t")
  output.puts(hl_all_unique.size)
end
