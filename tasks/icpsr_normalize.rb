# frozen_string_literal: true

require_relative '../lib/lsp-data'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

writer = MARC::XMLWriter.new("#{output_dir}/icpsr_normalized.marcxml")
reader = MARC::XMLReader.new("#{input_dir}/icpsr_bibs.xml", parser: 'magic', ignore_namespace: true)
reader.each do |record|
  record.fields(%w[610 630 650]).select { |field| field['2']&.downcase =~ /icpsr/ }.each do |field|
    field.subfields.delete_if { |subfield| subfield.code == '0' && subfield.value =~ /id\.loc\.gov/ }
    field.subfields.delete_if { |subfield| subfield.code == '2' && subfield.value.downcase =~ /icpsr/ }
    field.append(MARC::Subfield.new('2', 'icpsr'))
  end
  writer.write(record)
end
writer.close
