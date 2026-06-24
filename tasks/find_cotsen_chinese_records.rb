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

def normalize_field(field, type)
  return nil if field.nil?

  case type
  when 'title'
    field = field.split[0, 5].join(' ').gsub(/[\s\p{P}]/, '')
  when 'city'
    field = field.gsub(/[\s\p{P}]/, '')[0, 5]
  when 'name'
    field = field.split[0, 2].join(' ').gsub(/[\s\p{P}]/, '')
  end
  field.downcase.unicode_normalize(:nfd).gsub(/\p{InCombiningDiacriticalMarks}/, '')
end

### Returns a publication city found in a 260a/264a field.
### Preference is given to 264 fields with certain indicators, as shown
### in the 'publication_city_from_f264' method

def publication_city(record)
  city = publication_city_from_f264(record) || record.fields('260').find { |f| f['a'] }
  city ? city['a'] : nil
end

def publication_city_from_f264(record)
  f264 = record.fields('264').select { |f| f['a'] }
  preferred_order = %w[1 4 2 3 0]
  preferred_order.each do |indicator|
    field = f264.find { |f| f.indicator2 == indicator }
    return field if field
  end
  nil
end

### Returns an array with the full list of names found in a list of 1xx/7xx fields
### Entire field is returned so that the field tag can be analyzed by the name_overlap method

def names(record)
  record.fields(%w[100 110 111 130 700 710 711 730])
end

### Given two arrays of name fields, detects if there is at least one name in common
### Fuzzy prefix matching is used.  This method automatically returns true if 
### at least one of the input arrays is empty, or if the arrays have non-overlapping
### sets of tag suffixes (the suffix being the last two digits of the tag).  So, e.g. 
### if one array contains fields 100 and 700, and the other 110 and 710, then the test
### is not done and true is returned.  The idea is to bypass the name matching when the 
### two records do not contain the same types of names.

def name_overlap?(names_a, names_b)
  return true if names_a.empty? || names_b.empty?
  return true unless tag_suffix_list(names_a).intersect?(tag_suffix_list(names_b))

  names_a_norm = names_a.map { |name| normalize_field(name['a'], 'name') }
  names_b_norm = names_b.map { |name| normalize_field(name['a'], 'name') }
  prefix_overlap(names_a_norm, names_b_norm).any?
end

def prefix_overlap?(_names_a, _names_b)
  names_a_norm.select do |name_a|
    names_b_norm.any? { |name_b| name_a.start_with?(name_b) || name_b.start_with?(name_a) }
  end
end

def tag_suffix_list(fields)
  fields.map { |f| f.tag[1, 2] }
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
    next unless name_overlap?(alma_names, oclc_names)

    oclcnos << oclc_record['001'].value.gsub(/[^0-9]/, '')
  end
  puts("#{mmsid}\t#{oclcnos.join(',')}") if oclcnos.any?
  processed += 1
end
