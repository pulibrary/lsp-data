# frozen_string_literal: true

### As an acquisitions director, I want to know how many books we received on approval
###   with full cataloging from YBP were actually cataloged by YBP
###   so I can assess the value of our shelf-ready services.

### In light of moving towards using OCLC to enhance on-order records,
###   it could reduce reliance on vendors to provide cataloging.

### To do this report, it entails having access to all OCLC records
###   that we hold and comparing those records with the bib records
###   associated with YBP orders.
### If the 040$a from the OCLC record is `YDXCP`, that means YBP is the
###   original cataloging agency. If the 040$d is `YDXCP`, that means YBP contributed
###   cataloging work

### It would also be interesting to know how many of our YBP records are
###   cataloged by PCC or LC

require_relative '../lib/lsp-data'
require 'csv'

def all_oclc_nums(record)
  oclc = []
  record.fields('035').each do |field|
    field.subfields.each do |subfield|
      value = oclc_normalize(oclc: subfield.value,
                             input_prefix: true,
                             output_prefix: false)
      oclc << value if value
    end
  end
  Set.new(oclc.uniq)
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Retrieve a list of bib records with print inventory associated with YBP orders
### See DAS Reports for Review -> Physical Titles linked to YBP orders
mms_info = {}
csv = CSV.open("#{input_dir}/Physical Titles linked to YBP orders.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  mms_info[row['MMS Id']] ||= {}
  mms_info[row['MMS Id']][:vendors] ||= []
  mms_info[row['MMS Id']][:oclc] ||= []
  mms_info[row['MMS Id']][:vendors] << { vendor: row['Vendor Code'], account: row['Vendor Account Code'] }
end

### Export the bibs from Alma that are associated with them
### Go through the records and add the OCLC numbers to the mms_info hash
filename = "#{input_dir}/BIBLIOGRAPHIC_46368804430006421_46368804410006421_1.xml"
MARC::XMLReader.new(filename, parser: 'magic', ignore_namespace: true).each do |record|
  mms_id = record['001'].value
  next unless mms_info.member?(mms_id)

  mms_info[mms_id][:oclc] = oclcs(record: record)
end

### Go through the full dump of OCLC holdings (current as of July 2025) and create a hash with the following:
### 1. 040 field
### 2. Definitive OCLC number
### 3. All xref OCLC numbers
### 4. 042$a values
### Write out the matching OCLC records to a file for future processing
all_alma_oclc = Set.new(mms_info.values.map { |info| info[:oclc] }.flatten)
oclc_info = {}
xref_to_oclc = {}
writer = MARC::XMLWriter.new("#{output_dir}/oclc_records_for_ybp_orders.marcxml")
### Skip records not in mms_info
Dir.glob("#{input_dir}/pul_oclc/metacoll*.mrc").each do |file|
  MARC::Reader.new(file).each do |record|
    all_oclc = all_oclc_nums(record)
    next unless all_alma_oclc.intersect?(all_oclc)

    writer.write(record)
    definitive_number = oclcs(record: record).first
    all_oclc.each do |xref|
      xref_to_oclc[xref] = definitive_number
    end
    oclc_info[definitive_number] = {}
    f042_values = record.fields('042').map do |field|
      field.subfields.select { |subfield| subfield.code == 'a' }.map(&:value)
    end.flatten.uniq
    oclc_info[definitive_number][:f042] = f042_values.to_a
    oclc_info[definitive_number][:f040] = record['040']
  end
end
writer.close
### Per vendor account, report the following:
###   how many total records there are
###   how many with 040$d of YDXCP
###   how many with 040$a of YDXCP
###   how many with 040$a of DLC
###   how many with 042 of pcc or lc
###   how many have no match to OCLC holdings
vendor_to_mms = {}
mms_info.each do |mms_id, info|
  info[:vendors].each do |vendor_info|
    vendor_to_mms[vendor_info[:vendor]] ||= {}
    vendor_to_mms[vendor_info[:vendor]][vendor_info[:account]] ||= []
    vendor_to_mms[vendor_info[:vendor]][vendor_info[:account]] << mms_id
  end
end

output = File.open("#{output_dir}/ybp_cataloging_activity.tsv", 'w')
output.write("Vendor\tVendor Account\tMMS ID\tNot in OCLC\tOCLC Number\tHas 042 PCC\tHas 040d YDXCP\t")
output.puts("Has 040$a YDXCP\tHas 040$a DLC\tEntire 040\tAll 042")
vendor_to_mms.each do |vendor, accounts|
  accounts.each do |account, mms_ids|
    mms_ids.size
    mms_ids.each do |mms_id|
      alma_info = mms_info[mms_id]
      matching_oclc = alma_info[:oclc].select { |num| xref_to_oclc.member?(num) }
      if matching_oclc.empty?
        output.puts("#{vendor}\t#{account}\t#{mms_id}\tTRUE\t\tFALSE\tFALSE\tFALSE\tFALSE")
      else
        real_oclc_nums = matching_oclc.map { |num| xref_to_oclc[num] }.uniq
        real_oclc_nums.each do |oclc_num|
          output.write("#{vendor}\t#{account}\t#{mms_id}\tFALSE\t#{oclc_num}\t")
          oclc = oclc_info[oclc_num]
          pcc = %w[pcc lc].intersect?(oclc[:f042])
          f040d_ydx = oclc[:f040].subfields.any? { |subfield| subfield.code == 'd' && subfield.value =~ /^YDX/ }
          f040a_ydx = oclc[:f040]['a'][0..2] == 'YDX'
          f040a_dlc = oclc[:f040]['a'][0..2] == 'DLC'
          output.write("#{pcc}\t#{f040d_ydx}\t#{f040a_ydx}\t#{f040a_dlc}\t")
          output.puts("#{oclc[:f040]}\t#{oclc[:f042].join(' | ')}")
        end
      end
    end
  end
end
output.close
