# frozen_string_literal: true

### Filename should be HT.PUL.alma.mono.<creation date (yyyymmdd)>.mrc
### Needs to be binary MARC

### If a field is too large for the binary MARC format and it is a 505 field, remove the field
### Remove management tags and tags related to items and portfolios
### If a record is too large, remove all 505 fields

### Only include a record if there is a 583 that has $f of `HathiTrust` and $5 of `NjP`
require_relative '../lib/lsp-data'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

date = Time.new.strftime('%Y%m%d')
fname = "HT.PUL.alma.mono.#{date}.mrc"
MARC::Writer.new("#{output_dir}/#{fname}") do |writer|
  Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
    MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
      next unless record.fields('583').any? { |field| field['f'] == 'HathiTrust' && field['5'] == 'NjP' }

      record = field_delete_by_tags(record: record, tags: %w[876 950 952 951 953 954]) # item fields and management tags
      record.fields.delete_if { |field| field.tag == '505' && invalid_field_length?(field) }
      record = field_delete_by_tags(record: record, tags: %w[505]) if invalid_record_length?(record)
      writer.write(record)
    end
  end
end
