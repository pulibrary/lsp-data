# frozen_string_literal: true

### Acceptance criteria:
### - The 653 field of Activity books found in 9963637633506421 is replaced with the target 
###   field of `655 _7 $a Activity books. $2 lcgft
### - A mapping mechanism is developed in the script to translate lines of the spreadsheet into 
###   a hash of source values and target values

require_relative './../lib/lsp-data'
require 'CSV'
require 'byebug'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

replacements_file = "#{input_dir}/653_replacements.csv"
replacements = []
CSV.foreach(replacements_file, headers: true) do |row|
  source_string = row[0].strip
  source_field = MARC::DataField.new('653', ' ', ' ', ['a',source_string])
  replacement_string = row[1]
  r_tag = replacement_string[0..2]
  r_ind1 = replacement_string[4]
  r_ind2 = replacement_string[5]
  r_content = replacement_string[7..]
  replacement_field = MARC::DataField.new(r_tag, r_ind1, r_ind2)
  r_content.split('$').each do |sf|
      next if sf == ""
      sfcode = sf[0]
      sfcontent = sf[1..].strip
      replacement_field.append(MARC::Subfield.new(sfcode,sfcontent))
  end
  replacements << {source_field: source_field, replacement_field: replacement_field, ignore_indicators: true}
end

marc_file = "#{input_dir}/653_original.marcxml"
marc_reader = MARC::XMLReader.new(marc_file, parser: 'magic', ignore_namespace: true)
marc_writer = MARC::XMLWriter.new("#{output_dir}/653_replaced.marcxml")
marc_reader.each do |record|
  count_653_before = record.fields('653').size
  record = MarcCleanup.replace_fields(field_array: replacements, record: record)
  marc_writer.write(record) if count_653_before != record.fields('653').size
end
marc_writer.close

term_hash = {}
changed_mmsids = []
marc_reader = MARC::XMLReader.new("#{output_dir}/653_replaced.marcxml", parser: 'magic', ignore_namespace: true)
marc_reader.each do |record|
  changed_mmsids << record["001"].value
  record.fields('653').each do |f|
    term = f['a'].strip
    term_hash[term] ||= { before_count: 0, after_count: 0 }
    term_hash[term][:after_count] += 1
  end
end 

marc_reader = MARC::XMLReader.new("#{output_dir}/653_original.marcxml", parser: 'magic', ignore_namespace: true)
marc_reader.each do |record|
  record.fields('653').each do |f|
    term = f['a'].strip
    term_hash[term] ||= { before_count: 0, after_count: 0 }
    term_hash[term][:before_count] += 1
    if !changed_mmsids.include?(record["001"].value)
      term_hash[term][:after_count] += 1
    end
  end
end

File.open("#{output_dir}/653_report.tsv", 'w') do |output|
  output.puts("Term\tBefore count\tAfter count")
  term_hash.each do |term, counts|
    output.puts("#{term}\t#{counts[:before_count].to_s}\t#{counts[:after_count].to_s}")
  end
end