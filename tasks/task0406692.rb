# frozen_string_literal: true

### I'm looking for an Alma report of all the manuscripts we physically hold
###   with a preference for a more inclusive report that I can filter.
###   Extract based on LDR 06=d, f, t.
###   I assume this will generate the 135,672 records listed in the catalog.
###   If possible, exclude from that all records with only an electronic holding.

### Requested Fields: MMS id, title, call no., location. 008: date1, date2, lang. LDR: encoding level. Fields 300, 338.

### To produce an accurate report, constituent and host records need to be incorporated
### This means that a bib record can have no holdings of its own but be attached to a host record
require_relative '../lib/lsp-data'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Store physical holdings information for host records separately for merging in later
host_records = {}

### Store physical holdings and bibliographic information
bib_info = {}

### If there is no inventory and no 773 field with an MMS ID in $w, skip the record
### If there is no inventory and there is a 773 field, include the record
### If there is physical inventory, include the record

### Store the 008 value as a string in case the 008 is missing; this requires adding 4 to the positions in the report
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd' # Alma publishes suppressed records with a record status of "Deleted"

    mms_id = record['001'].value
    f852 = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ } # physical holding
    f773 = record.fields('773').select { |field| field['w'] =~ /^99[0-9]+6421$/ } # Host record IDs
    next if f773.empty? && f852.empty? # not a constituent and no physical inventory

    if %w[d f t].include?(record.leader[6]) # type of record is manuscript material
      holdings_call_nums = call_num_from_alma_holding_field(record: record, field_tag: '852', inst_suffix: '6421',
                                                            lc_only: false)
      locations = f852.map { |field| { holding_id: field['8'], library: field['b'], location: field['c'] } }
      bib_info[mms_id] = {
        title: title(record), holdings_call_nums: holdings_call_nums, locations: locations,
        f008: record['008'].to_s, leader: record.leader, hosts: f773.map { |field| field['w'] },
        f300: record.fields('300').map(&:to_s), f338: record.fields('338').map(&:to_s)
      }
    end
    f774 = record.fields('774').select { |field| field['w'] =~ /^99[0-9]+6421$/ } # Constituent record IDs
    next unless f774.size.positive?

    holdings_call_nums = call_num_from_alma_holding_field(record: record, field_tag: '852', inst_suffix: '6421',
                                                          lc_only: false)
    locations = f852.map { |field| { holding_id: field['8'], library: field['b'], location: field['c'] } }
    host_records[mms_id] =
      { holdings_call_nums: holdings_call_nums, locations: locations, constituents: f774.map { |field| field['w'] } }
  end
end
host_records.each do |host_id, host_info|
  host_info[:constituents].each do |constituent_id|
    next unless bib_info[constituent_id]

    bib_info[constituent_id][:hosts] << host_id # in case the constituent record doesn't have the host ID
    bib_info[constituent_id][:locations] += host_info[:locations]
    bib_info[constituent_id][:holdings_call_nums].merge!(host_info[:holdings_call_nums])
  end
end
output = File.open("#{output_dir}/task0406692.tsv", 'w')
output.write("MMS ID\tTitle\tHolding ID\tCall Number From Holdings\tLibrary\t")
output.puts("Location\tDate1\tDate2\tLanguage Code\tEncoding Level\t300 Field\t338 Field\tHost IDs")
bib_info.each do |mms_id, info|
  info[:locations].each do |location_info|
    call_num = info[:holdings_call_nums][location_info[:holding_id]]&.full_call_num
    output.write("#{mms_id}\t")
    output.write("#{info[:title]}\t")
    output.write("#{location_info[:holding_id]}\t")
    output.write("#{call_num}\t")
    output.write("#{location_info[:library]}\t")
    output.write("#{location_info[:location]}\t")
    output.write("#{info[:f008][11..14]}\t") # Date1
    output.write("#{info[:f008][15..18]}\t") # Date2
    output.write("#{info[:f008][39..41]}\t") # Language Code
    output.write("#{info[:leader][17]}\t") # Encoding Level
    output.write("#{info[:f300].join(' | ')}\t")
    output.write("#{info[:f338].join(' | ')}\t")
    output.puts(info[:hosts].uniq.join(' | '))
  end
end
