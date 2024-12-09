# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

### Helper method to determine which call number to assign
def preferred_lc_call_num(record:, inst_suffix:)
  all_call_nums = all_call_nums_from_merged_bib(record: record,
                                                inst_suffix: inst_suffix,
                                                lc_only: true,
                                                holding_field_tag: '852')
  holdings_with_call_nums = all_call_nums[:holdings].reject do |_id, call_nums|
    call_nums.nil?
  end
  holding_preferred = holdings_with_call_nums.values.first
  return holding_preferred.first unless holding_preferred.nil?

  f050_preferred = all_call_nums[:f050].select { |call_num| call_num.lc? && call_num.primary_subfield }
  return f050_preferred.first unless f050_preferred.empty?

  f090_preferred = all_call_nums[:f090].select { |call_num| call_num.lc? && call_num.primary_subfield }
  return f090_preferred.first unless f090_preferred.empty?

  nil
end

### Helper method to determine fiscal year of date
def fiscal_year_of_date(date)
  if date < Time.new(2020, 7, 1)
    'fy20'
  elsif date < Time.new(2021, 7, 1)
    'fy21'
  elsif date < Time.new(2022, 7, 1)
    'fy22'
  elsif date < Time.new(2023, 7, 1)
    'fy23'
  elsif date < Time.new(2024, 7, 1)
    'fy24'
  else
    'fy25'
  end
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
inst_suffix = ENV['ALMA_INST_SUFFIX']
item_fiscal_year = {}
csv = CSV.open("#{input_dir}/PUL Accessions.csv", 'r', headers: true)
csv.each do |row|
  barcode = row['Barcode']
  raw_date = row['Date']
  date_parts = raw_date.split('/')
  month = date_parts[0].to_i
  day = date_parts[1].to_i
  year = "20#{date_parts[2]}".to_i
  formatted_date = Time.new(year, month, day)
  fiscal_year = fiscal_year_of_date(formatted_date)
  item_fiscal_year[barcode] = fiscal_year
end

### Output the barcodes to create sets in Alma to publish the records with
###   holdings merged
pre_fy22 = item_fiscal_year.select { |_bc, fy| %w[fy20 fy21].include?(fy) }
File.open("#{output_dir}/pre_fy22_recap_accessions.csv", 'w') do |output|
  output.puts('Barcode')
  pre_fy22.each_key { |bc| output.puts(bc) }
end
post_fy22 = item_fiscal_year.reject { |_bc, fy| %w[fy20 fy21].include?(fy) }
File.open("#{output_dir}/post_fy22_recap_accessions.csv", 'w') do |output|
  output.puts('Barcode')
  post_fy22.each_key { |bc| output.puts(bc) }
end

### Iterate through publishing files to determine the call number of each item;
###   To be more efficient, export from Alma at the item level
###   Produce one call number per barcode
item_call_number = {} # barcode, call number
item_location = {} # barcode, concatenated library and location codes
Dir.glob("#{input_dir}/accessioned_records/pre_fy22_accessions*.xml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    item = record.fields('876').select do |field|
      field['a'] =~ /^23[0-9]+#{inst_suffix}$/
    end.first
    barcode = item['p']
    library = item['y']
    location = item['z']
    item_location[barcode] = "#{library}$#{location}"
    call_num = preferred_lc_call_num(record: record, inst_suffix: inst_suffix)
    item_call_number[barcode] = call_num
  end
end

### Produce report of barcode, location, year of accession, LC top-level classification,
###   LC sub-level classification, and full classification
File.open("#{output_dir}/recap_accessions_call_num_and_location.tsv", 'w') do |output|
  output.puts("Barcode\tFiscal Year\tLocation\tLC Top-Level\tLC Sub-Level\tLC Full Classification")
  item_fiscal_year.each do |barcode, fy|
    call_num = item_call_number[barcode]
    location = item_location[barcode]
    next if location.nil?

    output.write("#{barcode}\t")
    output.write("#{fy}\t")
    output.write("#{location}\t")
    if call_num
      output.write("#{call_num.primary_lc_class}\t")
      output.write("#{call_num.sub_lc_class}\t")
      output.puts(call_num.classification)
    else
      output.puts("\t\t")
    end
  end
end
