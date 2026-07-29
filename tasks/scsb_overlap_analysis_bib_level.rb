# frozen_string_literal: true

### 1 line for every title held by ReCAP partners (PUL, CUL, HL)
###   both in ReCAP and in OCLC (represented as onsite if the bib is also
###   not found within the partner ReCAP records), with the IDs of each system.
###  For holdings in OCLC that aren't in ReCAP, use the OCLC number as the ID.
###  There will be columns for the following buckets:

### Princeton ReCAP Shared
### Princeton ReCAP Private
### Princeton Onsite
### Columbia ReCAP Shared
### Columbia ReCAP Private
### Columbia Onsite
### Harvard ReCAP Shared [including HD]
### Harvard ReCAP Private [including HD]
### Harvard Onsite
### NYPL ReCAP Shared
### NYPL ReCAP Private
### NYPL Onsite

### Exclude records from OCLC that are coded as electronic
### Ignore the format marker in the GoldRush match key
require_relative '../lib/lsp-data'

def shared_recap_locations
  %w[recap$pa recap$gp mendel$qk firestone$pf marquand$pv]
end

def private_recap_locations
  %w[marquand$pj mendel$pk eastasian$pl stokes$pm lewis$pn engineer$pt
     firestone$pb mudd$ph lewis$ps arch$pw marquand$pz rare$xc rare$xg rare$xm
     rare$xn rare$xp rare$xr rare$xw rare$xx]
end

def shared_recap_location?(library:, location:)
  shared_recap_locations.include?("#{library}$#{location[0..1]}")
end

def private_recap_location?(library:, location:)
  private_recap_locations.include?("#{library}$#{location[0..1]}")
end

def princeton_onsite_location?(library:, location:)
  !shared_recap_location?(library: library,
                          location: location) && !private_recap_location?(library: library,
                                                                          location: location)
end

def electronic_resource_5xx_f007?(record)
  record.fields(%w[533 590]).any? { |f| f['a'] =~ /[Ee]lectronic reproduction/ } ||
    record.fields('007').any? { |f| f.value[0].downcase == 'c' }
end

def electronic_resource_3xx?(record)
  record.fields('300').any? { |f| f['a'] =~ /[Oo]nline resource/ } ||
    record.fields('337').any? { |f| f['a'] =~ /^c/ || f['b'] == 'c' }
end

def electronic_resource?(record)
  (record['245'] && record['245']['h'] =~ /electronic resource/) ||
    electronic_resource_3xx?(record) ||
    electronic_resource_5xx_f007?(record) ||
    (record['086'] && record['856'])
end

### There could be other uses for the electronic indicator for the SCSB dumps, so retain it
def partners_output_match_keys(input:, output:, type: 'xml')
  reader = if type == 'xml'
             MARC::XMLReader.new(input, parser: 'magic')
           else
             MARC::Reader.new(input, external_encoding: 'utf-8', invalid: :replace, replace: '')
           end
  reader.each do |record|
    next if type != 'xml' && electronic_resource?(record)

    match_key = MarcMatchKey::Key.new(record).key
    output.puts("#{record['001'].value}\t#{match_key}")
  end
end

### Ignore final character of match key (electronic indicator)
def add_matches_from_file(file:, matches:, inst_symbol:)
  File.open(file, 'r') do |input|
    while (line = input.gets)
      parts = line.split("\t") # MMS ID and Key
      key = parts[1].chomp[0..-2]
      matches[key] ||= {}
      matches[key][inst_symbol] ||= []
      matches[key][inst_symbol] << parts[0]
    end
  end
  matches
end

def output_match_report_headers(output)
  output.write("Match Key\tPUL Onsite?\tPUL Onsite IDs\tPUL Shared?\tPUL Shared IDs\tPUL Private?\tPUL Private IDs\t")
  output.write("CUL Onsite?\tCUL Onsite IDs\tCUL Shared?\tCUL Shared IDs\tCUL Private?\tCUL Private IDs\t")
  output.write("HL Onsite?\tHL Onsite IDs\tHL Shared?\tHL Shared IDs\tHL Private?\tHL Private IDs\t")
  output.puts("NYPL Onsite?\tNYPL Onsite IDs\tNYPL Shared?\tNYPL Shared IDs\tNYPL Private?\tNYPL Private IDs\t")
end

def site_order
  %i[pulonsite pulshared pulprivate
     culonsite culshared culprivate
     hlonsite hlshared hlprivate
     nyplonsite nyplshared nyplprivate]
end

def output_match_report_line(output:, key:, sites:)
  output.write("#{key}\t")
  site_order.each do |site|
    if sites[site]
      output.write("TRUE\t")
      output.write(sites[site].join(' | ').to_s)
    else
      output.write("FALSE\t")
    end
    site == site_order[-1] ? output.puts('') : output.write("\t")
  end
end

def valid_pul_record?(record)
  record.leader[5] != 'd' && record.fields('852').any? { |field| field['8'] =~ /^22[0-9]+6421$/ }
end

def output_statistics_per_site(site_title:, unique_count:, matches:, site:, output:)
  output.write("#{site_title}\t")
  output.write("#{unique_count}\t")
  output.puts(matches.values.select { |sites| sites[site] }.size)
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Make tab-delimited files of each institution's IDs with
###   the match key for further overlap analysis
File.open("#{output_dir}/cul_scsb_shared_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

File.open("#{output_dir}/cul_scsb_private_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/cul/scsb_private/*.xml").each do |file|
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

File.open("#{output_dir}/hl_scsb_shared_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

File.open("#{output_dir}/hl_scsb_private_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/hl/scsb_private/*.xml").each do |file|
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

File.open("#{output_dir}/nypl_scsb_shared_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
    puts File.basename(file)
    partners_output_match_keys(input: file, output: output)
  end
end

File.open("#{output_dir}/nypl_scsb_private_match_keys.tsv", 'w') do |output|
  Dir.glob("#{input_dir}/partners/nypl/scsb_private/*.xml").each do |file|
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

### Produce match keys for all PUL bibs
recap_private = File.open("#{output_dir}/pul_scsb_private_match_keys.tsv", 'w')
recap_shared = File.open("#{output_dir}/pul_scsb_shared_match_keys.tsv", 'w')
onsite = File.open("#{output_dir}/pul_onsite_match_keys.tsv", 'w')
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next unless valid_pul_record?(record)

    holdings = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
    shared_locations = holdings.select do |field|
      shared_recap_location?(library: field['b'], location: field['c'])
    end
    private_locations = holdings.select do |field|
      private_recap_location?(library: field['b'], location: field['c'])
    end
    onsite_locations = holdings.select do |field|
      princeton_onsite_location?(library: field['b'], location: field['c'])
    end

    shared_holding_ids = shared_locations.map { |field| field['8'] }
    shared_items = record.fields('876').any? { |field| shared_holding_ids.include?(field['0']) }
    private_holding_ids = private_locations.map { |field| field['8'] }
    private_items = record.fields('876').any? { |field| private_holding_ids.include?(field['0']) }
    onsite_holding_ids = onsite_locations.map { |field| field['8'] }
    onsite_items = record.fields('876').any? { |field| onsite_holding_ids.include?(field['0']) }
    match_key = MarcMatchKey::Key.new(record).key
    id = record['001'].value
    recap_shared.puts("#{id}\t#{match_key}") if shared_items
    recap_private.puts("#{id}\t#{match_key}") if private_items
    onsite.puts("#{id}\t#{match_key}") if onsite_items
  end
end
recap_shared.close
recap_private.close
onsite.close

### Load in the match keys
matches = {}
add_matches_from_file(file: "#{output_dir}/pul_scsb_shared_match_keys.tsv", matches: matches, inst_symbol: :pulshared)
add_matches_from_file(file: "#{output_dir}/pul_scsb_private_match_keys.tsv", matches: matches, inst_symbol: :pulprivate)
add_matches_from_file(file: "#{output_dir}/pul_onsite_match_keys.tsv", matches: matches, inst_symbol: :pulonsite)
add_matches_from_file(file: "#{output_dir}/cul_scsb_shared_match_keys.tsv", matches: matches, inst_symbol: :culshared)
add_matches_from_file(file: "#{output_dir}/cul_scsb_private_match_keys.tsv", matches: matches, inst_symbol: :culprivate)
add_matches_from_file(file: "#{output_dir}/cul_oclc_match_keys.tsv", matches: matches, inst_symbol: :culonsite)
add_matches_from_file(file: "#{output_dir}/hl_scsb_shared_match_keys.tsv", matches: matches, inst_symbol: :hlshared)
add_matches_from_file(file: "#{output_dir}/hl_scsb_private_match_keys.tsv", matches: matches, inst_symbol: :hlprivate)
add_matches_from_file(file: "#{output_dir}/hl_oclc_match_keys.tsv", matches: matches, inst_symbol: :hlonsite)
add_matches_from_file(file: "#{output_dir}/nypl_scsb_shared_match_keys.tsv", matches: matches, inst_symbol: :nyplshared)
add_matches_from_file(file: "#{output_dir}/nypl_scsb_private_match_keys.tsv", matches: matches,
                      inst_symbol: :nyplprivate)
add_matches_from_file(file: "#{output_dir}/nypl_oclc_match_keys.tsv", matches: matches, inst_symbol: :nyplonsite)

### If a key is found in SCSB, assume that's the OCLC holding copy
matches.each_value do |sites|
  sites.delete(:culonsite) if sites[:culprivate] || sites[:culshared]
  sites.delete(:hlonsite) if sites[:hlprivate] || sites[:hlshared]
  sites.delete(:nyplonsite) if sites[:nyplprivate] || sites[:nyplshared]
end

### Output 1 line per match key, with columns for each site that contain the IDs and flags for any records in the site
### All keys
File.open("#{output_dir}/recap_partner_sites_per_key.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### Keys found in more than one site
File.open("#{output_dir}/recap_partner_sites_per_key_matches_only.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    next unless sites.size > 1

    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### PUL and other institutions
File.open("#{output_dir}/recap_partner_sites_per_key_pul_and_others.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    site_values = sites.keys.map(&:to_s)
    next unless site_values.any? { |site| site[0] == 'p' } && site_values.any? { |site| site[0] != 'p' }

    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### Only unique titles per site
File.open("#{output_dir}/recap_partner_sites_per_key_unique_titles.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    next unless sites.size == 1

    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### Only unique titles per institution
File.open("#{output_dir}/recap_partner_institutions_per_key_unique_titles.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    institutions = sites.keys.map(&:to_s).uniq
    next unless institutions.size == 1

    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### Report of holdings in ReCAP
File.open("#{output_dir}/recap_partner_sites_per_key_recap_only.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    site_values = sites.keys.map(&:to_s)
    recap_sites = %w[pulshared culshared hlshared nyplshared pulprivate culprivate hlprivate nyplprivate]
    next unless site_values.intersect?(recap_sites)

    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### All ReCAP shared sites
File.open("#{output_dir}/recap_partner_sites_per_key_all_recap_shared.tsv", 'w') do |output|
  output_match_report_headers(output)
  matches.each do |key, sites|
    site_values = sites.keys.map(&:to_s)
    next unless %w[pulshared culshared hlshared nyplshared].intersection(site_values).size == 4

    output_match_report_line(output: output, key: key, sites: sites)
  end
end

### Produce summary report of how many unique titles per site compared to total number of titles per site
pul_shared_unique = matches.select { |_key, sites| sites[:pulshared] && sites.size == 1 }.size
pul_private_unique = matches.select { |_key, sites| sites[:pulprivate] && sites.size == 1 }.size
pul_onsite_unique = matches.select { |_key, sites| sites[:pulonsite] && sites.size == 1 }.size
cul_shared_unique = matches.select { |_key, sites| sites[:culshared] && sites.size == 1 }.size
cul_private_unique = matches.select { |_key, sites| sites[:culprivate] && sites.size == 1 }.size
cul_onsite_unique = matches.select { |_key, sites| sites[:culonsite] && sites.size == 1 }.size
hl_shared_unique = matches.select { |_key, sites| sites[:hlshared] && sites.size == 1 }.size
hl_private_unique = matches.select { |_key, sites| sites[:hlprivate] && sites.size == 1 }.size
hl_onsite_unique = matches.select { |_key, sites| sites[:hlonsite] && sites.size == 1 }.size
nypl_shared_unique = matches.select { |_key, sites| sites[:nyplshared] && sites.size == 1 }.size
nypl_private_unique = matches.select { |_key, sites| sites[:nyplprivate] && sites.size == 1 }.size
nypl_onsite_unique = matches.select { |_key, sites| sites[:nyplonsite] && sites.size == 1 }.size
all_sites_unique = matches.select { |_key, sites| sites.size == 1 }.size

site_output = File.open("#{output_dir}/recap_overlap_statistics_by_site.tsv", 'w')
site_output.puts("Site\tNumber of Unique Titles\tTotal Number of Titles")
output_statistics_per_site(site_title: 'PUL ReCAP Shared', unique_count: pul_shared_unique,
                           matches: matches, site: :pulshared, output: site_output)
output_statistics_per_site(site_title: 'PUL ReCAP Private', unique_count: pul_private_unique,
                           matches: matches, site: :pulprivate, output: site_output)
output_statistics_per_site(site_title: 'PUL Onsite', unique_count: pul_onsite_unique,
                           matches: matches, site: :pulonsite, output: site_output)
output_statistics_per_site(site_title: 'CUL ReCAP Shared', unique_count: cul_shared_unique,
                           matches: matches, site: :culshared, output: site_output)
output_statistics_per_site(site_title: 'CUL ReCAP Private', unique_count: cul_private_unique,
                           matches: matches, site: :culprivate, output: site_output)
output_statistics_per_site(site_title: 'CUL Onsite', unique_count: cul_onsite_unique,
                           matches: matches, site: :culonsite, output: site_output)
output_statistics_per_site(site_title: 'HL ReCAP Shared', unique_count: hl_shared_unique,
                           matches: matches, site: :hlshared, output: site_output)
output_statistics_per_site(site_title: 'HL ReCAP Private', unique_count: hl_private_unique,
                           matches: matches, site: :hlprivate, output: site_output)
output_statistics_per_site(site_title: 'HL Onsite', unique_count: hl_onsite_unique,
                           matches: matches, site: :hlonsite, output: site_output)
output_statistics_per_site(site_title: 'NYPL ReCAP Shared', unique_count: nypl_shared_unique,
                           matches: matches, site: :nyplshared, output: site_output)
output_statistics_per_site(site_title: 'NYPL ReCAP Private', unique_count: nypl_private_unique,
                           matches: matches, site: :nyplprivate, output: site_output)
output_statistics_per_site(site_title: 'NYPL Onsite', unique_count: nypl_onsite_unique,
                           matches: matches, site: :nyplonsite, output: site_output)
site_output.puts("All Sites\t#{all_sites_unique}\t#{matches.size}")
site_output.close

### Summary report of how many unique titles there are per institution
pul_total = 0
pul_unique = 0
cul_total = 0
cul_unique = 0
hl_total = 0
hl_unique = 0
nypl_total = 0
nypl_unique = 0
matches.each_value do |sites|
  institutions = sites.keys.map { |site| site.to_s[0] }.uniq
  pul_total += 1 if institutions.include?('p')
  pul_unique += 1 if institutions == %w[p]
  cul_total += 1 if institutions.include?('c')
  cul_unique += 1 if institutions == %w[c]
  hl_total += 1 if institutions.include?('h')
  hl_unique += 1 if institutions == %w[h]
  nypl_total += 1 if institutions.include?('n')
  nypl_unique += 1 if institutions == %w[n]
end

all_institutions_unique = matches.values.select do |sites|
  sites.keys.map { |site| site.to_s[0] }.uniq.size == 1
end.size

File.open("#{output_dir}/recap_overlap_statistics_by_institution.tsv", 'w') do |output|
  output.puts("Institution\tNumber of Unique Titles\tTotal Number of Titles")
  output.write("PUL\t")
  output.write("#{pul_unique}\t")
  output.puts(pul_total)
  output.write("CUL\t")
  output.write("#{cul_unique}\t")
  output.puts(cul_total)
  output.write("HL\t")
  output.write("#{hl_unique}\t")
  output.puts(hl_total)
  output.write("NYPL\t")
  output.write("#{nypl_unique}\t")
  output.puts(nypl_total)
  output.write("All Institutions\t")
  output.write("#{all_institutions_unique}\t")
  output.puts(matches.size)
end

### ReCAP-only summary reports (1 includes private)
pul_recap_total = matches.values.select { |sites| %i[pulshared pulprivate].intersect?(sites.keys) }.size
cul_recap_total = matches.values.select { |sites| %i[culshared culprivate].intersect?(sites.keys) }.size
hl_recap_total = matches.values.select { |sites| %i[hlshared hlprivate].intersect?(sites.keys) }.size
nypl_recap_total = matches.values.select { |sites| %i[nyplshared nyplprivate].intersect?(sites.keys) }.size
all_recap_total = matches.values.select { |sites| sites.keys.map(&:to_s).any? { |site| site =~ /shared|private/ } }.size
pul_recap_shared_total = matches.values.select { |sites| sites.keys.include?(:pulshared) }.size
cul_recap_shared_total = matches.values.select { |sites| sites.keys.include?(:culshared) }.size
hl_recap_shared_total = matches.values.select { |sites| sites.keys.include?(:hlshared) }.size
nypl_recap_shared_total = matches.values.select { |sites| sites.keys.include?(:nyplshared) }.size
all_recap_shared_total = matches.values.select { |sites| sites.keys.map(&:to_s).any? { |site| site =~ /shared/ } }.size
pul_recap_unique = 0
cul_recap_unique = 0
hl_recap_unique = 0
nypl_recap_unique = 0
pul_recap_shared_unique = 0
cul_recap_shared_unique = 0
hl_recap_shared_unique = 0
nypl_recap_shared_unique = 0
all_recap_sites = %i[pulshared pulprivate culshared culprivate hlshared hlprivate nyplshared nyplprivate]
all_shared_recap_sites = %i[pulshared culshared hlshared nyplshared]
matches.each_value do |sites|
  recap_sites = all_recap_sites.intersection(sites.keys)
  pul_recap_unique += 1 if %i[pulshared
                              pulprivate].intersect?(recap_sites) && (recap_sites - %i[pulshared pulprivate]).empty?
  cul_recap_unique += 1 if %i[culshared
                              culprivate].intersect?(recap_sites) && (recap_sites - %i[culshared culprivate]).empty?
  hl_recap_unique += 1 if %i[hlshared
                             hlprivate].intersect?(recap_sites) && (recap_sites - %i[hlshared hlprivate]).empty?
  nypl_recap_unique += 1 if %i[nyplshared
                               nyplprivate].intersect?(recap_sites) && (recap_sites - %i[nyplshared nyplprivate]).empty?
  if recap_sites.include?(:pulshared) && all_shared_recap_sites.intersection(recap_sites).size == 1
    pul_recap_shared_unique += 1
  end
  if recap_sites.include?(:culshared) && all_shared_recap_sites.intersection(recap_sites).size == 1
    cul_recap_shared_unique += 1
  end
  if recap_sites.include?(:hlshared) && all_shared_recap_sites.intersection(recap_sites).size == 1
    hl_recap_shared_unique += 1
  end
  if recap_sites.include?(:nyplshared) && all_shared_recap_sites.intersection(recap_sites).size == 1
    nypl_recap_shared_unique += 1
  end
end

File.open("#{output_dir}/recap_overlap_statistics_by_institution_all_recap.tsv", 'w') do |output|
  output.puts("Institution\tNumber of Unique Titles\tTotal Number of Titles")
  output.write("PUL\t")
  output.write("#{pul_recap_unique}\t")
  output.puts(pul_recap_total)
  output.write("CUL\t")
  output.write("#{cul_recap_unique}\t")
  output.puts(cul_recap_total)
  output.write("HL\t")
  output.write("#{hl_recap_unique}\t")
  output.puts(hl_recap_total)
  output.write("NYPL\t")
  output.write("#{nypl_recap_unique}\t")
  output.puts(nypl_recap_total)
  output.write("All Institutions\t")
  output.write("#{pul_recap_unique + cul_recap_unique + hl_recap_unique + nypl_recap_unique}\t")
  output.puts(all_recap_total)
end
File.open("#{output_dir}/recap_overlap_statistics_by_institution_all_recap_shared.tsv", 'w') do |output|
  output.puts("Institution\tNumber of Unique Titles\tTotal Number of Titles")
  output.write("PUL\t")
  output.write("#{pul_recap_shared_unique}\t")
  output.puts(pul_recap_shared_total)
  output.write("CUL\t")
  output.write("#{cul_recap_shared_unique}\t")
  output.puts(cul_recap_shared_total)
  output.write("HL\t")
  output.write("#{hl_recap_shared_unique}\t")
  output.puts(hl_recap_shared_total)
  output.write("NYPL\t")
  output.write("#{nypl_recap_shared_unique}\t")
  output.puts(nypl_recap_shared_total)
  output.write("All Institutions\t")
  total_unique = pul_recap_shared_unique + cul_recap_shared_unique + hl_recap_shared_unique + nypl_recap_shared_unique
  output.write("#{total_unique}\t")
  output.puts(all_recap_shared_total)
end
