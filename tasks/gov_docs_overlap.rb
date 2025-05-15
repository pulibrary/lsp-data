# frozen_string_literal: true

### Compare the bibs that have portfolios in `US Government Documents` against
###   the bibs that have portfolios in 'Marcive GPO Government Documents'
###   using the match key algorithm

require_relative './../lib/lsp-data'
require 'nokogiri'
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Make spreadsheets with MMS ID and match key to allow for re-running
###   without regenerating the match keys
File.open("#{output_dir}/marcive_match_keys.tsv", 'w') do |output|
  output.puts("MMS ID\tMatch Key")
  reader = MARC::XMLReader.new("#{input_dir}/marcive_bibs.xml", parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    match_key = MarcMatchKey::Key.new(record).key
    output.puts("#{record['001'].value}\t#{match_key}")
  end
end
File.open("#{output_dir}/gov_docs_match_keys.tsv", 'w') do |output|
  output.puts("MMS ID\tMatch Key")
  reader = MARC::XMLReader.new("#{input_dir}/gov_docs_bibs.xml", parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    match_key = MarcMatchKey::Key.new(record).key
    output.puts("#{record['001'].value}\t#{match_key}")
  end
end

### Step 2: perform match key overlap analysis
marcive_match_keys = {}
gov_docs_match_keys = {}
File.open("#{input_dir}/marcive_match_keys.tsv", 'r') do |input|
  input.gets
  while line = input.gets
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    match_key = parts[1]
    marcive_match_keys[match_key] ||= []
    marcive_match_keys[match_key] << mms_id
  end
end
File.open("#{input_dir}/gov_docs_match_keys.tsv", 'r') do |input|
  input.gets
  while line = input.gets
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    match_key = parts[1]
    gov_docs_match_keys[match_key] ||= []
    gov_docs_match_keys[match_key] << mms_id
  end
end

### Step 3: Create reports of MMS ID and OCLC number for each collection
File.open("#{output_dir}/marcive_oclc_nums.tsv", 'w') do |output|
  output.puts("MMS ID\OCLC Numbers")
  reader = MARC::XMLReader.new("#{input_dir}/marcive_bibs.xml", parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclc_nums = LspData.oclcs(record: record)
    output.puts("#{record['001'].value}\t#{oclc_nums.join(' | ')}")
  end
end
File.open("#{output_dir}/gov_docs_oclc_nums.tsv", 'w') do |output|
  output.puts("MMS ID\tOCLC Numbers")
  reader = MARC::XMLReader.new("#{input_dir}/gov_docs_bibs.xml", parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclc_nums = LspData.oclcs(record: record)
    output.puts("#{record['001'].value}\t#{oclc_nums.join(' | ')}")
  end
end

### Step 4: Create hashes for OCLC numbers as keys and MMS IDs as values
marcive_oclc_nums = {}
gov_docs_oclc_nums = {}
File.open("#{output_dir}/marcive_oclc_nums.tsv", 'r') do |input|
  input.gets
  while line = input.gets
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    raw_nums = parts[1]
    oclc_nums = raw_nums.nil? ? [''] : raw_nums.split(' | ')
    oclc_nums.each do |num|
      marcive_oclc_nums[num] ||= []
      marcive_oclc_nums[num] << mms_id
    end
  end
end
File.open("#{output_dir}/gov_docs_oclc_nums.tsv", 'r') do |input|
  input.gets
  while line = input.gets
    line.chomp!
    parts = line.split("\t")
    mms_id = parts[0]
    raw_nums = parts[1]
    oclc_nums = raw_nums.nil? ? [''] : raw_nums.split(' | ')
    oclc_nums.each do |num|
      gov_docs_oclc_nums[num] ||= []
      gov_docs_oclc_nums[num] << mms_id
    end
  end
end
overlap_oclc = (gov_docs_oclc_nums.keys & marcive_oclc_nums.keys)

### Step 5: Find bib match pairs, since a record
###   can have multiple OCLC numbers
oclc_overlap_bibs = {}
overlap_oclc.each do |oclc_num|
  marcive_bibs = marcive_oclc_nums[oclc_num].sort
  gov_docs_bibs = gov_docs_oclc_nums[oclc_num].sort
  marcive_bibs.each do |marcive|
    gov_docs_bibs.each do |gov_docs|
      oclc_overlap_bibs[marcive] ||= []
      oclc_overlap_bibs[marcive] << gov_docs
    end
  end
end

### Step 6: Output all Gov Docs matches
File.open("#{output_dir}/marcive_bibs_gov_docs_matches.tsv", 'w') do |output|
  output.puts("Marcive MMS ID\tGov Docs MMS IDs")
  oclc_overlap_bibs.each do |marcive, gov_docs|
    output.write("#{marcive}\t")
    output.puts(gov_docs.join(' | '))
  end
end

### Step 7: Find matches across the entire database of electronic titles
###   based on OCLC numbers and match key
marcive_all_oclc_matches = {}
marcive_all_match_key_matches = {}
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    e_inventory = record.fields('951').select { |f| f['0'] =~ /6421$/ && f['n'] !~ /Marcive/ }.size
    next unless e_inventory.positive?

    mms_id = record['001'].value
    match_key = MarcMatchKey::Key.new(record).key
    marcive_matches = marcive_match_keys[match_key]
    marcive_matches&.each do |marcive_bib|
      marcive_all_match_key_matches[marcive_bib] ||= []
      marcive_all_match_key_matches[marcive_bib] << mms_id
    end
    oclc_nums = LspData.oclcs(record: record)
    oclc_nums.each do |oclc_num|
      matches = marcive_oclc_nums[oclc_num]
      next if matches.nil?

      matches.each do |marcive_bib|
        marcive_all_oclc_matches[marcive_bib] ||= []
        marcive_all_oclc_matches[marcive_bib] << mms_id
      end
    end
  end
end

### Output the Marcive matches with the US Government Documents collection only
all_gov_docs = Set.new(gov_docs_match_keys.values.flatten)
File.open("#{output_dir}/marcive_gov_docs_matches.tsv", 'w') do |output|
  output.puts("Marcive MMS ID\tMatch Key\tNumber of OCLC Matches\tNumber of Match Key Matches")
  marcive_match_keys.each do |match_key, marcive_bibs|
    marcive_bibs.each do |marcive_bib|
      match_key_matches = marcive_all_match_key_matches[marcive_bib]&.select { |id| all_gov_docs.include?(id) }
      oclc_matches = marcive_all_oclc_matches[marcive_bib]&.select { |id| all_gov_docs.include?(id) }
      output.write("#{marcive_bib}\t")
      output.write("#{match_key}\t")
      output.write("#{oclc_matches&.size}\t")
      output.puts(match_key_matches&.size)
    end
  end
end

### Output each Marcive MMS ID and all of its matches
File.open("#{output_dir}/marcive_all_matches.tsv", 'w') do |output|
  output.puts("Marcive MMS ID\tMatch Key\tNumber of OCLC Matches\tNumber of Match Key Matches")
  marcive_match_keys.each do |match_key, marcive_bibs|
    marcive_bibs.each do |marcive_bib|
      match_key_matches = marcive_all_match_key_matches[marcive_bib]
      oclc_matches = marcive_all_oclc_matches[marcive_bib]
      output.write("#{marcive_bib}\t")
      output.write("#{match_key}\t")
      output.write("#{oclc_matches&.size}\t")
      output.puts(match_key_matches&.size)
    end
  end
end
