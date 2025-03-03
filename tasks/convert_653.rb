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
replacements = Hash.new
CSV.foreach(replacements_file, headers: true) do |row|
  source_string = row[0]
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
  replacements[source_string] = replacement_field
end

marc_file = "#{input_dir}/653_original.marcxml"
marc_reader = MARC::XMLReader.new(marc_file, parser: 'magic', ignore_namespace: true)
marc_writer = MARC::XMLWriter.new("#{output_dir}/653_replaced.marcxml")
marc_reader.each do |record|
  record_changed = false
  record.fields('653').each do |f|
    if f.subfields.count == 1
      f653_content = f['a']
      if replacements.key?(f653_content)    
        source_field = MARC::DataField.new('653', ' ', ' ', ['a',f653_content])
        record = MarcCleanup.replace_field(source_field: source_field,
                                           replacement_field: replacements[f653_content],
                                           record: record,
                                           ignore_indicators: true)
        record_changed = true
      end
    end
  end 
  marc_writer.write(record) if record_changed
end
marc_writer.close
             