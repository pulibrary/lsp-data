# frozen_string_literal: true

# - [ ] A full export is performed that excludes the material types listed above [leader position 6 is equal to `a`]
# - [ ] Exclude all `online` library locations
# - [ ] Exclude all `obsolete` library locations
# - [ ] Exclude all `resshare` library locations
# - [ ] Exclude all `techserv` library locations
# - [ ] Exclude the following microform locations
#   - [ ] recap$pe
#   - [ ] firestone$docsm
#   - [ ] firestone$flm
#   - [ ] firestone$flmm
#   - [ ] firestone$flmp
#   - [ ] firestone$gestf
#   - [ ] eastasian$hygf
#   - [ ] firestone$flmb
#   - [ ] lewis$mic
#   - [ ] eastasian$ql
#   - [ ] firestone$pf
#   - [ ] stokes$mic
#   - [ ] mudd$mic
#   - [ ] marquand$mic
#   - [ ] engineer$mic
# - [ ] Exclude records with only electronic inventory

require_relative './../lib/lsp-data'

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

def has_physical?(record:, exclude_libraries:, exclude_locations:)
  wanted_f852 = record.fields('852').reject do |field|
    field['8'] =~ /^22/ &&
      (exclude_libraries.include?(field['b']) ||
        exclude_locations.include?("#{field['b']}$#{field['c']}"))
  end
  wanted_f852.each do |holding_field|
    holding_id = holding_field['8']
    return true if record.fields('876').any? { |field| field['a'] =~ /^23/ && field['0'] == holding_id }
  end
  false
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

fname = 'google_export'
fnum = 0
rec_num = 0
writer = nil
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[6] != 'a'
    next if record.leader[5] == 'd'
    next unless has_physical?(record: record,
                              exclude_libraries: exclude_libraries,
                              exclude_locations: exclude_locations)

    if rec_num % 100_000 == 0
      writer.close if writer
      fnum += 1
      writer = MARC::XMLWriter.new("#{output_dir}/#{fname}_#{fnum}.marcxml")
    end
    writer.write(record)
    rec_num += 1
  end
end
writer.close

### Next, find which of these records have a conflict between the 001 and the
###   035$z that has the Voyager bib ID:
###   If there is more than one unique 035$z, report it, or
###     if it doesn't correspond to the Alma version of the 001
writer = MARC::XMLWriter.new("#{output_dir}/google_records_with_conflict.marcxml")
Dir.glob("#{output_dir}/google_export*.marcxml").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    mms_id = record['001'].value
    next unless mms_id =~ /3506421$/

    voyager_equivalent = mms_id.gsub(/^99([0-9]+)3506421$/, '\1')
    f035 = record.fields('035').select do |f|
      f['z'] =~ /^\(NjP\)Voyager/
    end.map { |f| f['z'].gsub(/^\(NjP\)Voyager([0-9]+)$/, '\1') }.uniq
    writer.write(record) unless f035.size == 1 && f035.first == voyager_equivalent
  end
end
