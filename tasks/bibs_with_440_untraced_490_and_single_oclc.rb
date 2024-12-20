# frozen_string_literal: true

### Find all unsuppressed bibs with 440 fields or an untraced 490 field
###   and a single OCLC number; ignore CZ records, as they can't be updated

require_relative './../lib/lsp-data'
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

output = MARC::XMLWriter.new("#{output_dir}/bibs_with_440_single_oclc.marcxml")
untraced = MARC::XMLWriter.new("#{output_dir}/bibs_with_untraced_490_single_oclc.marcxml")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    cz = record.fields('035').select { |f| f['a'] =~ /^\(EXLCZ\)/ }
    next if cz.size.positive?
    next if record.leader[5] == 'd'

    oclc_nums = oclcs(record: record)
    next if oclc_nums.size != 1

    output.write(record) if record['440']
    f490 = record.fields('490').reject { |f| f.indicator1 == '0' }
    untraced.write(record) if f490.size.positive?
  end
end
output.close
untraced.close
