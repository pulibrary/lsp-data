# frozen_string_literal: true

### Find all unsuppressed bibs with 440 fields and a single OCLC number

require_relative './../lib/lsp-data'
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

output = MARC::XMLWriter.new("#{output_dir}/bibs_with_440_single_oclc.marcxml")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd'

    oclc_nums = oclcs(record: record)
    next if oclc_nums.size != 1

    f440 = record.fields('440')
    output.write(record) if f440.size.positive?
  end
end
