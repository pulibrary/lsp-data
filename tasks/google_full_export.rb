# frozen_string_literal: true

require_relative '../lib/lsp-data'

exclude_locations = %w[
  recap$pe
  firestone$docsm
  firestone$flm
  firestone$flmm
  firestone$flmp
  firestone$gestf
  eastasian$hygf
  firestone$flmb
  lewis$mic
  eastasian$ql
  firestone$pf
  stokes$mic
  mudd$mic
  marquand$mic
  engineer$mic
]
exclude_libraries = %w[online obsolete resshare techserv RES_SHARE]

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  GoogleExport.new(exclude_libraries: exclude_libraries,
                   exclude_locations: exclude_locations,
                   input_file: file,
                   output_dir: output_dir)
end

### Generate a sample file with 100 monograph bibs and 100 serial bibs
mono_count = 0
serial_count = 0
writer = MARC::XMLWriter.new("#{output_dir}/google_record_sample.marcxml")
Dir.glob("#{output_dir}/filtered_fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    break if mono_count == 100 && serial_count == 100

    rec_type = record.leader[7]
    next if rec_type == 'm' && mono_count == 100
    next if rec_type == 's' && serial_count == 100

    if rec_type == 'm'
      mono_count += 1
      writer.write(record)
    elsif rec_type == 's'
      serial_count += 1
      writer.write(record)
    end
  end
  break if mono_count == 100 && serial_count == 100
end

### Next, find which of these records have a conflict between the 001 and the
###   035$z that has the Voyager bib ID:
###   If there is more than one unique 035$z, report it, or
###     if it doesn't correspond to the Alma version of the 001
writer = MARC::XMLWriter.new("#{output_dir}/google_records_with_conflict.marcxml")
Dir.glob("#{output_dir}/filtered_fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    mms_id = record['001'].value
    next unless mms_id =~ /3506421$/

    voyager_equivalent = mms_id.gsub(/^99([0-9]+)3506421$/, '\1')
    f035 = record.fields('035').select do |f|
      f['z'] =~ /^\(NjP\)Voyager/
    end
    f035.map! { |f| f['z'].gsub(/^\(NjP\)Voyager([0-9]+)$/, '\1') }
    f035.uniq!
    next if f035.empty?

    writer.write(record) unless f035.size == 1 && f035.first == voyager_equivalent
  end
end
