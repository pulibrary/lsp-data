# frozen_string_literal: true

### Given a file of MARCXML records, for each one:
### - Performs a Z39.50 query in WorldCat, matching on title and publication date
### - Filters out the returned records based on various criteria
### - Creates a tab-delimited report (written to STDOUT) with the MMS ID
###   and a comma-delimited list of OCLC Nos that meet the criteria.  If no qualifying
###   WorldCat records are found, no row is output
###
###   This particular task is meant to find copy-cataloging candidates for Cotsen Chinese
###   records, but the general approach could be applied to other languages and collections.

require_relative '../lib/lsp-data'

### Applies normalizations/truncations based on the field type:
### - Title: Truncated to first 5 words, spaces/punctuation removed after
### - City: Truncated to first 5 characters after spaces/punctuation removed
### - Name: Truncated to first 2 words, spaces/punctuation removed after
### All types are normalized to lowercase as a last step

def normalize_field(orig_field, type)
  return nil if orig_field.nil?

  case type
  when 'title'
    orig_field.split[0, 5].join(' ').gsub(/[\s\p{P}]/, '').downcase
  when 'city'
    orig_field.gsub(/[\s\p{P}]/, '')[0, 5].downcase
  when 'name'
    orig_field.split[0, 2].join(' ').gsub(/[\s\p{P}]/, '').downcase
  end
end

### Returns the first publication city found in a 260a/264a field

def publication_city(record)
  all_cities = record.fields(%w[260 264])
  all_cities.any? ? all_cities[0]['a'] : nil
end

### Returns an array with the full list of names found in all 100a/700a fields

def names(record)
  all_names = record.fields(%w[100 700])
  all_names.map { |f| f['a'] }
end

### Given two arrays of names, detects if there is at least one name in common

def name_overlap?(names_a, names_b)
  return true if names_a.empty? || names_b.empty?

  overlap = names_a.select do |name_a|
    names_b.any? { |name_b| name_a.start_with?(name_b) || name_b.start_with?(name_a) }
  end
  overlap.any?
end

def new_connection
  Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                      credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
processed = 0
reader = MARC::XMLReader.new("#{input_dir}/Cotsen_Chinese_No_Parallel_Title.xml",
                             parser: 'magic', ignore_namespace: true)
conn = nil
reader.each do |alma_record|
  mmsid = alma_record['001'].value
  oclcnos = []
  alma_date = alma_record['008'].value[7, 4]
  alma_title = alma_record['245']['a'].sub(/[\s\p{P}=]+$/, '').sub(/(?<=..\S)\s*[(=].*$/, '').gsub('"', '\"')
  alma_title_norm = normalize_field(alma_title, 'title')
  alma_pubcity = normalize_field(publication_city(alma_record), 'city')
  alma_names = names(alma_record)
  next unless alma_date =~ /[0-9]{4}/

  conn = new_connection if (processed % 1_000).zero? || conn.nil?
  query = "@and @attr 1=4 @attr 3=2 @attr 4=1 \"#{alma_title}\" @attr 1=31 \"#{alma_date}\""
  conn.search(query).each do |oclc_record|
    oclc_title_norm = normalize_field(oclc_record['245']['a'], 'title')
    oclc_parallel_title = oclc_record.fields('880').find { |field| field['6'][0..2] == '245' }
    oclc_pubcity = normalize_field(publication_city(oclc_record), 'city')
    oclc_names = names(oclc_record)

    next if (oclc_record['040']['b'] != 'eng') || oclc_parallel_title.nil? ||
            (oclc_record['008'].value[7, 4] != alma_date) || (alma_pubcity != oclc_pubcity)
    next unless oclc_title_norm.start_with?(alma_title_norm) ||
                alma_title_norm.start_with?(oclc_title_norm)
    next unless name_overlap?(alma_names.map { |name| normalize_field(name, 'name') },
                              oclc_names.map { |name| normalize_field(name, 'name') })

    oclcnos << oclc_record['001'].value.gsub(/[^0-9]/, '')
  end
  puts("#{mmsid}\t#{oclcnos.join(',')}") if oclcnos.any?
  processed += 1
end
