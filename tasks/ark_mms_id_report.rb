# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Load in the ARKs, appending the URL stem to the front
url_stem = 'https://arks.princeton.edu/ark:/'
arks = []
Dir.glob("#{input_dir}/ark_file*.txt").each do |file|
  File.open(file, 'r') do |input|
    while (line = input.gets)
      line.chomp!
      line.strip!
      arks << "#{url_stem}#{line}"
    end
  end
end
arks.uniq!

### Step 2: Go through a full dump and find all records with 856 fields;
###   convert the url to https, then compare with the arks provided;
###   write out the MMS ID and URL for each match
output = File.open("#{output_dir}/ark_mms_id_report.tsv", 'w')
output.puts("MMS ID\tURL\tARK")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    f856 = record.fields('856').select { |f| f['u'] =~ /arks\.princeton\.edu/ }
    next if f856.empty?

    mms_id = record['001'].value
    f856.each do |field|
      raw_url = field['u']
      url = raw_url.dup
      url.gsub!(/^http:(.*)$/, 'https:\1')
      if arks.include?(url)
        ark = url.gsub(%r{^https://arks.princeton.edu/ark:/(.*)$}, '\1')
        output.puts("#{mms_id}\t#{raw_url}\t#{ark}")
      end
    end
  end
end
output.close

### Step 3: Go through all portfolio URLs to find more matches;
### This requires 2 separate reports in Analytics;
### 1. Find all portfolios where the `Portfolio URL` contains `arks.princeton.edu`
### 2. Final all portfolios where the `Static URL (override)` contains `arks.princeton.edu`
output = File.open("#{output_dir}/ark_portfolio_id_report.tsv", 'w')
output.puts("MMS ID\tPortfolio ID\tPortfolio URL\tARK")
Dir.glob("#{input_dir}/portfolio_arks*.csv").each do |file|
  csv = CSV.open(file, 'r', headers: true, encoding: 'bom|utf-8')
  csv.each do |row|
    mms_id = row['MMS Id']
    portfolio_id = row['Portfolio Id']
    raw_url = row['Portfolio URL']
    raw_url.gsub!(/^jkey=(.*)$/, '\1')
    url = raw_url.dup
    url.gsub!(/^http:(.*)$/, 'https:\1')
    if arks.include?(url)
      ark = url.gsub(%r{^https://arks.princeton.edu/ark:/(.*)$}, '\1')
      output.puts("#{mms_id}\t#{portfolio_id}\t#{raw_url}\t#{ark}")
    end
  end
end
output.close

### Step 4: Combine the reports in Excel, with the final output
###   having the following 3 columns:
###   1. MMS ID
###   2. URL in Alma
###   3. ARK
### Use Conditional Formatting to highlight ARKs that are associated with
###   more than one MMS ID
