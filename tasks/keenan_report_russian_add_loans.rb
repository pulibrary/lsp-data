# frozen_string_literal: true

### Add loan data for MMS IDs from `PUL Print IDs`

require_relative './../lib/lsp-data'
require 'csv'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Load in the MMS IDs from the report and create a hash that will include loan data
mms_to_loans = {}

File.open("#{input_dir}/keenan_report_russian_08-2025.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_ids = parts[15].split(' | ')
    mms_ids.each { |mms_id| mms_to_loans[mms_id] = { browses: 0, loans: 0 } }
  end
end

### Output the MMS IDs to use in an Analytics report that provides
###   the total number of loans that are not-in-house and the total number of in-house loans
File.open("#{output_dir}/keenan_report_pul_ids.csv", 'w') do |output|
  output.puts('MMS Id')
  mms_to_loans.each_key { |mms_id| output.puts(mms_id) }
end

### SQL query used:
### SELECT
###   "Bibliographic Details"."MMS Id",
###   "Physical Item Details"."Num of Loans Including Pre-Migration (Not In House)",
###   "Physical Item Details"."Num of Loans Including Pre-Migration (In House)"
### FROM "Physical Items"

### Had to split the query into 2 files since there were over 17,000 bibs
Dir.glob("#{input_dir}/keenan_loans_*.csv").each do |file|
  csv = CSV.open(file, 'r', headers: true, encoding: 'bom|utf-8')
  csv.each do |row|
    mms_to_loans[row['mms_id']][:browses] = row['in_house'].to_i
    mms_to_loans[row['mms_id']][:loans] = row['not_in_house'].to_i
  end
end

### Write out new report, going line by line through the original report
output = File.open("#{output_dir}/keenan_report_russian_08-2025_with_loans.tsv", 'w')
output.write("GoldRush Key\tLanguage\tPlace of Publication\tPublisher\tDate of Publication\t")
output.write("Date From 008\tTitle\tAuthor\tLC Call Number\tISBNs\tISSNs\tLCCNs\tOCLC Numbers\t")
output.write("Total Count of IDs\tPUL Electronic IDs\tPUL Print IDs\tPUL Print Locations\tPUL CGDs\t")
output.write("CUL IDs\tCUL CGDs\tHL IDs\tHL CGDs\tNYPL IDs\tNYPL CGDs\t")
output.write("Institution of Cataloging Information\tSource of Cataloging Information\t")
output.puts("PUL Browses\tPUL Loans")
File.open("#{input_dir}/keenan_report_russian_08-2025.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    mms_ids = parts[15].split(' | ')
    if mms_ids.empty?
      output.puts("#{line}\t\t")
    else
      total_loans = 0
      total_browses = 0
      mms_ids.each do |mms_id|
        info = mms_to_loans[mms_id]
        total_loans += info[:loans] if info
        total_browses += info[:browses] if info
      end
      output.write("#{line}\t")
      output.puts("#{total_browses}\t#{total_loans}")
    end
  end
end
output.close
