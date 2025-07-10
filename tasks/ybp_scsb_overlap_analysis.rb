# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'bigdecimal'
require 'csv'

def eligible_record?(record)
  record.leader[7] == 'm' &&
    record['008'] &&
    %w[2022 2023 2024 2025].include?(record['008'].value[7..10]) &&
    record['020']
end

def recap_locations
  %w[
    recap$gp recap$jq recap$pa firestone$pb recap$pe firestone$pf mudd$ph
    mudd$phr marquand$pj mendel$pk eastasian$pl stokes$pm lewis$pn recap$pq
    lewis$ps engineer$pt marquand$pv arch$pw marquand$pz mendel$qk eastasian$ql
    recap$qv rare$xc rare$xcr rare$xg rare$xgr rare$xm rare$xmr rare$xn rare$xp
    rare$xr rare$xrr rare$xw rare$xx
  ]
end

def recap_location?(library:, location:)
  recap_locations.include?("#{library}$#{location}")
end

### Step 1: Make tab-delimited files of each institution's SCSB IDs with
###   the match key for further overlap analysis

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

File.open("#{output_dir}/cul_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/CUL_20250415_070000/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
  Dir.glob("#{input_dir}/partners/cul/CUL_20250421_095200/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
end

File.open("#{output_dir}/cul_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/metacoll*recentcul*.mrc").each do |file|
    puts File.basename(file)
    reader = MARC::Reader.new(file)
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
end

File.open("#{output_dir}/hl_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/HL_20250415_230000/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
  Dir.glob("#{input_dir}/partners/hl/HL_20250421_091500/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
end

File.open("#{output_dir}/hul_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/metacoll*hulrecent*.mrc").each do |file|
    puts File.basename(file)
    reader = MARC::Reader.new(file)
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
end

File.open("#{output_dir}/nypl_scsb_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/NYPL_20250415_150000/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
  Dir.glob("#{input_dir}/partners/nypl/NYPL_20250421_101000/*.xml").each do |file|
    puts File.basename(file)
    reader = MARC::XMLReader.new(file, parser: 'magic')
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
end

File.open("#{output_dir}/nypl_oclc_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/metacoll*nyplrecent*.mrc").each do |file|
    puts File.basename(file)
    reader = MARC::Reader.new(file)
    reader.each do |record|
      next unless eligible_record?(record)

      match_key = MarcMatchKey::Key.new(record).key
      id = record['001'].value
      output.puts("#{id}\t#{match_key}")
    end
  end
end

### Step 2: Produce match keys for all PUL bibs with print inventory
recap = File.open("#{output_dir}/pul_recap_match_keys.tsv", 'w')
non_recap = File.open("#{output_dir}/pul_non_recap_match_keys.tsv", 'w')
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless eligible_record?(record)
    next unless record.fields.any? { |field| field.tag == '876' && field['0'] =~ /6421$/ }

    locations = record.fields('852').select { |field| field['8'] =~ /^22.*6421$/ }
                      .map { |field| recap_location?(library: field['b'], location: field['c']) }
    match_key = MarcMatchKey::Key.new(record).key
    id = record['001'].value
    recap.puts("#{id}\t#{match_key}") if locations.include?(true)
    non_recap.puts("#{id}\t#{match_key}") if locations.include?(false)
  end
end
recap.close
non_recap.close

### Step 3: Perform overlap analysis; for each institution,
###   the match key is the key, bib IDs are the values
matches = {}
File.open("#{output_dir}/pul_non_recap_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:oclcpul] << id
  end
end

File.open("#{output_dir}/pul_recap_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:scsbpul] << id
  end
end

File.open("#{output_dir}/cul_scsb_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:scsbcul] << id
  end
end
File.open("#{output_dir}/hl_scsb_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:scsbhl] << id
  end
end

File.open("#{output_dir}/nypl_scsb_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:scsbnypl] << id
  end
end

File.open("#{output_dir}/cul_oclc_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:oclccul] << id
  end
end
File.open("#{output_dir}/hul_oclc_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:oclchl] << id
  end
end

File.open("#{output_dir}/nypl_oclc_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    matches[key] ||= {
      scsbpul: [],
      scsbcul: [],
      scsbhl: [],
      scsbnypl: [],
      oclcpul: [],
      oclccul: [],
      oclchl: [],
      oclcnypl: []
    }
    matches[key][:oclcnypl] << id
  end
end

### Step 4: Output the ISBNs of matched titles that have
###   more than one institution; this will be used to retrieve prices from Gobi
ids_to_pull = { scsbcul: Set.new, scsbhl: Set.new, scsbnypl: Set.new, scsbpul: Set.new,
                oclccul: Set.new, oclchl: Set.new, oclcnypl: Set.new, oclcpul: Set.new }
multi_matches = matches.select do |_key, inst|
  inst.select { |_name, ids| ids.size.positive? }.size > 1
end
multi_matches.each_value do |inst|
  ids_to_pull[:scsbcul] += inst[:scsbcul]
  ids_to_pull[:scsbhl] += inst[:scsbhl]
  ids_to_pull[:scsbnypl] += inst[:scsbnypl]
  ids_to_pull[:scsbpul] += inst[:scsbpul]
  ids_to_pull[:oclccul] += inst[:oclccul]
  ids_to_pull[:oclchl] += inst[:oclchl]
  ids_to_pull[:oclcnypl] += inst[:oclcnypl]
  ids_to_pull[:oclcpul] += inst[:oclcpul]
end

isbns_to_look_up = []
ids_to_isbns = { scsbcul: {}, scsbpul: {}, scsbhl: {}, scsbnypl: {},
                 oclccul: {}, oclcpul: {}, oclchl: {}, oclcnypl: {} }
Dir.glob("#{input_dir}/partners/cul/CUL_20250415_070000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless ids_to_pull[:scsbcul].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:scsbcul][record['001'].value] = rec_isbns
    end
  end
end
Dir.glob("#{input_dir}/partners/cul/CUL_20250421_095200/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless ids_to_pull[:scsbcul].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:scsbcul][record['001'].value] = rec_isbns
    end
  end
end

Dir.glob("#{input_dir}/partners/hl/HL_20250415_230000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless ids_to_pull[:scsbhl].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:scsbhl][record['001'].value] = rec_isbns
    end
  end
end
Dir.glob("#{input_dir}/partners/hl/HL_20250421_091500/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless ids_to_pull[:scsbhl].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:scsbhl][record['001'].value] = rec_isbns
    end
  end
end

Dir.glob("#{input_dir}/partners/nypl/NYPL_20250415_150000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless ids_to_pull[:scsbnypl].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:scsbnypl][record['001'].value] = rec_isbns
    end
  end
end
Dir.glob("#{input_dir}/partners/nypl/NYPL_20250421_101000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    next unless ids_to_pull[:scsbnypl].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:scsbnypl][record['001'].value] = rec_isbns
    end
  end
end

Dir.glob("#{input_dir}/metacoll.PUL*recentcul*.mrc").each do |file|
  puts File.basename(file)
  reader = MARC::Reader.new(file)
  reader.each do |record|
    next unless ids_to_pull[:oclccul].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:oclccul][record['001'].value] = rec_isbns
    end
  end
end

Dir.glob("#{input_dir}/metacoll.PUL*hulrecent*.mrc").each do |file|
  puts File.basename(file)
  reader = MARC::Reader.new(file)
  reader.each do |record|
    next unless ids_to_pull[:oclchl].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:oclchl][record['001'].value] = rec_isbns
    end
  end
end

Dir.glob("#{input_dir}/metacoll.PUL*nyplrecent*.mrc").each do |file|
  puts File.basename(file)
  reader = MARC::Reader.new(file)
  reader.each do |record|
    next unless ids_to_pull[:oclcnypl].include?(record['001'].value)

    rec_isbns = isbns(record)
    if rec_isbns.size.positive?
      isbns_to_look_up += rec_isbns
      ids_to_isbns[:oclcnypl][record['001'].value] = rec_isbns
    end
  end
end

Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless ids_to_pull[:scsbpul].include?(record['001'].value) ||
                ids_to_pull[:oclcpul].include?(record['001'].value)

    rec_isbns = isbns(record)
    next unless rec_isbns.size.positive?

    isbns_to_look_up += rec_isbns
    ids_to_isbns[:scsbpul][record['001'].value] = rec_isbns if ids_to_pull[:scsbpul].include?(record['001'].value)
    ids_to_isbns[:oclcpul][record['001'].value] = rec_isbns if ids_to_pull[:oclcpul].include?(record['001'].value)
  end
end

### Import cost info for MMS IDs associated with YBP orders in Alma since
###   those ISBNs weren't searched in Gobi
mms_to_cost = {}
File.open("#{input_dir}/ybp_order_bibs_to_cost.csv", 'r', encoding: 'bom|utf-8') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split(',')
    mms_id = parts[0]
    list_price = parts[2]
    currency = parts[3]
    next if mms_to_cost[mms_id]
    next if ['', '0'].include?(list_price)

    mms_to_cost[mms_id] = case currency
                          when 'USD'
                            { us_cost: BigDecimal(list_price), uk_cost: BigDecimal('0') }
                          else
                            { us_cost: BigDecimal('0'), uk_cost: BigDecimal(list_price) }
                          end
  end
end
pul_isbns = []
reader = MARC::XMLReader.new("#{input_dir}/ybp_order_bibs.xml", parser: 'magic', ignore_namespace: true)
reader.each do |record|
  mms_id = record['001'].value
  next unless ids_to_pull[:scsbpul].include?(mms_id) ||
              ids_to_pull[:oclcpul].include?(mms_id)

  rec_isbns = isbns(record)
  next unless rec_isbns.size.positive?

  pul_isbns += rec_isbns

  cost = mms_to_cost[mms_id]
  rec_isbns.each { |isbn| isbn_to_cost[isbn] ||= mms_to_cost[mms_id] } if cost
  ids_to_isbns[:scsbpul][mms_id] = rec_isbns if ids_to_pull[:scsbpul].include?(mms_id)
  ids_to_isbns[:oclcpul][mms_id] = rec_isbns if ids_to_pull[:oclcpul].include?(mms_id)
end
isbns_to_look_up.uniq!

### Step 5: Get all the ISBNs from PUL records with YBP orders to reduce the number of
###   ISBNs to look up in Gobi
isbns_to_look_up -= pul_isbns
File.open("#{output_dir}/isbns_to_look_up_ybp.txt", 'w') do |output|
  output.puts('ISBN')
  isbns_to_look_up.each { |isbn| output.puts(isbn) }
end

### Step 6: Load in the ISBNs that Gobi returned as a hash with price
isbn_to_cost = {}
Dir.glob("#{input_dir}/ybp_exports/ItemsList*.txt").each do |file|
  File.open(file, 'r') do |input|
    input.gets
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      binding = parts[11].to_s
      next if binding.empty? || binding == 'eBook'

      isbn = parts[10]
      us_cost = case parts[26].to_s
                when '', 'Not Known'
                  BigDecimal('0')
                else
                  BigDecimal(parts[26].gsub(/ USD$/, ''))
                end
      uk_cost = case parts[29].to_s
                when '', 'Not Known'
                  BigDecimal('0')
                else
                  BigDecimal(parts[29].gsub(/ GBP$/, ''))
                end
      isbn_to_cost[isbn] = { us_cost: us_cost, uk_cost: uk_cost }
    end
  end
end

### Step 7: Filter out the records that were not found in Gobi
found_isbns = isbn_to_cost.keys
ids_to_isbns.each_value do |id_hash|
  id_hash.delete_if { |_id, isbns| (found_isbns & isbns).empty? }
end

### Step 8: Find cost per title
cost_per_key = {}
matches.each do |key, inst|
  scsbpul_matches = inst[:scsbpul].select { |id| ids_to_isbns[:scsbpul].include?(id) }
  oclcpul_matches = inst[:oclcpul].select { |id| ids_to_isbns[:oclcpul].include?(id) }
  scsbcul_matches = inst[:scsbcul].select { |id| ids_to_isbns[:scsbcul].include?(id) }
  oclccul_matches = inst[:oclccul].select { |id| ids_to_isbns[:oclccul].include?(id) }
  scsbhl_matches = inst[:scsbhl].select { |id| ids_to_isbns[:scsbhl].include?(id) }
  oclchl_matches = inst[:oclchl].select { |id| ids_to_isbns[:oclchl].include?(id) }
  scsbnypl_matches = inst[:scsbnypl].select { |id| ids_to_isbns[:scsbnypl].include?(id) }
  oclcnypl_matches = inst[:oclcnypl].select { |id| ids_to_isbns[:oclcnypl].include?(id) }
  title_cost = nil
  scsbpul_matches.each do |id|
    next if title_cost

    isbns = ids_to_isbns[:scsbpul][id]
    isbns.each do |isbn|
      cost = isbn_to_cost[isbn]
      title_cost ||= cost if cost
    end
  end
  unless title_cost
    oclcpul_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:oclcpul][id]
      isbns.each do |isbn|
        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  unless title_cost
    scsbcul_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:scsbcul][id]
      isbns.each do |isbn|
        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  unless title_cost
    oclccul_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:oclccul][id]
      isbns.each do |isbn|
        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  unless title_cost
    oclchl_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:oclchl][id]
      isbns.each do |isbn|
        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  unless title_cost
    scsbhl_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:scsbhl][id]
      isbns.each do |isbn|
        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  unless title_cost
    oclcnypl_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:oclcnypl][id]
      isbns.each do |isbn|
        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  unless title_cost
    scsbnypl_matches.each do |id|
      next if title_cost

      isbns = ids_to_isbns[:scsbnypl][id]
      isbns.each do |isbn|
        next if title_cost

        cost = isbn_to_cost[isbn]
        title_cost ||= cost if cost
      end
    end
  end
  cost_per_key[key] = title_cost if title_cost
end

### Step 9: Write overall overlap analysis out;
output = File.open("#{output_dir}/pul_scsb_overlap_overview.tsv", 'w')
output.write("Match Key\tPUL ReCAP\tPUL non-ReCAP\tCUL ReCAP\tCUL non-ReCAP\tHUL ReCAP\tHUL non-ReCAP\t")
output.puts("NYPL ReCAP\tNYPL non-ReCAP\tAll Places\tUS Cost Per Title\tUK Cost Per Title")
matches.each do |key, inst|
  cost = cost_per_key[key]
  next unless cost

  match_institutions = inst.select { |place, ids| (ids_to_isbns[place].keys & ids).size.positive? }
  scsbpul_matches = inst[:scsbpul].select { |id| ids_to_isbns[:scsbpul].include?(id) }
  oclcpul_matches = inst[:oclcpul].select { |id| ids_to_isbns[:oclcpul].include?(id) }
  scsbcul_matches = inst[:scsbcul].select { |id| ids_to_isbns[:scsbcul].include?(id) }
  oclccul_matches = inst[:oclccul].select { |id| ids_to_isbns[:oclccul].include?(id) }
  scsbhl_matches = inst[:scsbhl].select { |id| ids_to_isbns[:scsbhl].include?(id) }
  oclchl_matches = inst[:oclchl].select { |id| ids_to_isbns[:oclchl].include?(id) }
  scsbnypl_matches = inst[:scsbnypl].select { |id| ids_to_isbns[:scsbnypl].include?(id) }
  oclcnypl_matches = inst[:oclcnypl].select { |id| ids_to_isbns[:oclcnypl].include?(id) }
  output.write("#{key}\t")
  output.write("#{scsbpul_matches.size.positive?}\t")
  output.write("#{oclcpul_matches.size.positive?}\t")
  output.write("#{scsbcul_matches.size.positive?}\t")
  output.write("#{oclccul_matches.size.positive?}\t")
  output.write("#{scsbhl_matches.size.positive?}\t")
  output.write("#{oclchl_matches.size.positive?}\t")
  output.write("#{scsbnypl_matches.size.positive?}\t")
  output.write("#{oclcnypl_matches.size.positive?}\t")
  output.write("#{match_institutions.keys.join(' | ')}\t")
  output.write("#{cost[:us_cost].to_s('F')}\t")
  output.puts(cost[:uk_cost].to_s('F'))
end
output.close

### Step 10: Find match keys that had PUL records in the report
match_keys = []
File.open("#{output_dir}/pul_scsb_overlap_overview.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    key = parts[0]
    pul_recap = parts[1]
    pul_other = parts[2]
    match_keys << key if pul_recap == 'true' || pul_other == 'true'
  end
end

### Step 11: Find the MMS IDs attached to those keys and export them to Alma Analytics
key_to_mms = {}
File.open("#{output_dir}/pul_recap_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    next unless match_keys.include?(key)

    key_to_mms[key] ||= []
    key_to_mms[key] << id
  end
end
File.open("#{output_dir}/pul_non_recap_match_keys.tsv", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    id = parts[0]
    key = parts[1]
    next unless match_keys.include?(key)

    key_to_mms[key] ||= []
    key_to_mms[key] << id
  end
end

File.open("#{output_dir}/matched_mms_ids.txt", 'w') do |out|
  key_to_mms.each_value do |ids|
    ids.each { |id| out.puts(id) }
  end
end

### Step 12: Create a hash of loans per MMS ID
mms_to_loan = {}
csv = CSV.open("#{input_dir}/loans_per_mms.csv", 'r', headers: true)
csv.each do |row|
  mms_to_loan[row['MMS Id']] = row['Loans (Not In House)'].to_i
end

### Step 13: Read in the original report; find the number of PUL loans per match key
output = File.open("#{output_dir}/ybp_overlap_report_with_pul_loans.tsv", 'w')
output.write("Match Key\tPUL Owns\tPUL ReCAP\tPUL non-ReCAP\tCUL ReCAP\tCUL non-ReCAP\t")
output.write("HUL ReCAP\tHUL non-ReCAP\tNYPL ReCAP\tNYPL non-ReCAP\t")
output.puts("Cost Per Item\tTotal Copies\tTotal Spent\tPotential Savings\tNumber of PUL Loans")
File.open("#{output_dir}/pul_scsb_overlap_overview.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    key = parts[0]
    pul_recap = parts[1]
    pul_non_recap = parts[2]
    pul_owns = [pul_recap, pul_non_recap].include?('true')
    cul_recap = parts[3]
    cul_non_recap = cul_recap == 'true' ? 'false' : parts[4]
    hul_recap = parts[5]
    hul_non_recap = hul_recap == 'true' ? 'false' : parts[6]
    nypl_recap = parts[7]
    nypl_non_recap = nypl_recap == 'true' ? 'false' : parts[8]
    all_owners = [
      pul_recap, pul_non_recap, cul_recap, cul_non_recap,
      hul_recap, hul_non_recap, nypl_recap, nypl_non_recap
    ].select { |value| value == 'true' }
    us_cost = BigDecimal(parts[10].gsub(/\s/, ''))
    uk_cost = BigDecimal(parts[11].gsub(/\s/, ''))
    cost = us_cost > BigDecimal('0') ? us_cost : uk_cost
    extra_copies = all_owners.size - 1
    total_spent = cost * all_owners.size
    savings = cost * extra_copies
    mms_ids = key_to_mms[key].to_a
    loan_info = mms_to_loan.select { |mms, _loans| mms_ids.include?(mms) }
    total_loans = 0
    loan_info.each_value { |loans| total_loans += loans }
    output.write("#{key}\t")
    output.write("#{pul_owns}\t#{pul_recap}\t#{pul_non_recap}\t")
    output.write("#{cul_recap}\t#{cul_non_recap}\t")
    output.write("#{hul_recap}\t#{hul_non_recap}\t")
    output.write("#{nypl_recap}\t#{nypl_non_recap}\t")
    output.write("#{cost.to_s('F')}\t")
    output.write("#{all_owners.size}\t")
    output.write("#{total_spent.to_s('F')}\t")
    output.write("#{savings.to_s('F')}\t")
    output.puts(total_loans)
  end
end
output.close
