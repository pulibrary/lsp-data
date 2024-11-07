# frozen_string_literal: true

### Acceptance criteria:
###   - All records with 773/774 fields with $w (NjP)[MMS ID] are found
###   - All 773/774 fields have the (NjP) prefix removed

### Since the records will be loaded with a merge rule,
###   I am reducing the records to the leader, 001, 773, and 774 fields

require_relative './../lib/lsp-data'
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
writer = MARC::XMLWriter.new("#{output_dir}/773_774_remove_prefix.marcxml")
targets = [
            { field: '773', subfields: ['w'] },
            { field: '774', subfields: ['w'] }
          ]
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    target_fields = record.fields(['773', '774']).select do |field|
      field['w'] =~ /^\(NjP\)99[0-9]+6421$/
    end
    next if target_fields.empty?

    record = MarcCleanup.remove_prefix_from_subfield(record: record,
                                                     targets: targets,
                                                     string: '(NjP)')
    new_record = MARC::Record.new
    new_record.leader = record.leader
    new_record << MARC::ControlField.new('001', record['001'].value)
    record.fields('773').each { |field| new_record << field }
    record.fields('774').each { |field| new_record << field }
    writer.write(new_record)
  end
end
writer.close
