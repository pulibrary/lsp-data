# frozen_string_literal: true

### As an acquisitions director, I want to know how many books we received on approval
###   with full cataloging from YBP were actually cataloged by YBP
###   so I can assess the value of our shelf-ready services.

### In light of moving towards using OCLC to enhance on-order records,
###   it could reduce reliance on vendors to provide cataloging.

### To do this report, it entails having access to all OCLC records
###   that we hold and comparing those records with the bib records
###   associated with YBP orders.
### If the 040$a from the OCLC record is `YDX`, that means YBP is the
###   original cataloging agency. If the 040$d is `YDX`, that means YBP contributed
###   cataloging work

### It would also be interesting to know how many of our YBP records are
###   cataloged by PCC or LC

require_relative '../lib/lsp-data'
require 'csv'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Retrieve a list of bib records with print inventory associated with YBP orders
### See DAS Reports for Review -> Physical Titles linked to YBP orders
mms_info = {}
csv = CSV.open("#{input_dir}/Physical Titles linked to YBP orders.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  mms_info[row['MMS Id']] ||= {}
  mms_info[row['MMS Id']][:vendors] ||= []
  mms_info[row['MMS Id']][:vendors] << { vendor: row['Vendor Code'], account: row['Vendor Account Code'] }
end

### Go through the full dump and add the OCLC numbers to the mms_info hash
Dir.glob("#{input_dur}/new_fulldump/fulldump*.xml*").each do |file|
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    mms_id = record['001'].value
    next unless mms_info.member?(mms_id)

    mms_info[mms_id][:oclc] = oclcs(record)
  end
end
