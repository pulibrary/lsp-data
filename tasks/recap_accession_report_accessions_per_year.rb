# frozen_string_literal: true

### Separate ReCAP accessions for PUL into one file per fiscal year;
### Make separate files for items still in ReCAP and items that were withdrawn
### Make a report for the withdrawn items;
###   only export the barcodes for current items for loading into Alma
require_relative './../lib/lsp-data'
require 'csv'

### Helper method to determine fiscal year of date
def fiscal_year_of_date(date)
  fiscal_year = date.year - 2000 # for months 1 through 6
  fiscal_year += 1 if date.month > 6
  "fy#{fiscal_year.to_s.rjust(2, '0')}"
end

### Given by the director of ReCAP
pul_customer_codes = %w[GP JQ PA PB PE PF PG PH PJ PK PL PM PN PQ PS PT PW PV
                        PZ QA QB QC QD QK QL QP QT QV QX]

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
withdrawn_by_fiscal_year = {}
current_by_fiscal_year = {}
csv = CSV.open("#{input_dir}/LAS Tables/table250108.full.if.csv", 'r', headers: true)
csv.each do |row|
  customer_code = row['Owner'].upcase
  next unless pul_customer_codes.include?(customer_code)

  hash = {}
  barcode = row['Item BarCode']
  raw_accession_date = row['Accession Date']
  accession_date_parts = raw_accession_date.split('/')
  accession_month = accession_date_parts[0].to_i
  accession_day = accession_date_parts[1].to_i
  accession_year = "20#{accession_date_parts[2]}".to_i
  hash[:accession_date] = Time.new(accession_year, accession_month, accession_day)
  hash[:accession_fiscal_year] = fiscal_year_of_date(hash[:accession_date])
  hash[:customer_code] = customer_code
  raw_withdrawal_date = row['Date Withdrawn']
  hash[:withdrawal_date] = nil
  hash[:withdrawal_fiscal_year] = nil
  unless raw_withdrawal_date == '?'
    wd_date_parts = raw_withdrawal_date.split('/')
    wd_month = wd_date_parts[0].to_i
    wd_day = wd_date_parts[1].to_i
    wd_year = "20#{wd_date_parts[2]}".to_i
    hash[:withdrawal_date] = Time.new(wd_year, wd_month, wd_day)
    hash[:withdrawal_fiscal_year] = fiscal_year_of_date(hash[:withdrawal_date])
  end
  if hash[:withdrawal_fiscal_year]
    withdrawn_by_fiscal_year[hash[:accession_fiscal_year]] ||= {}
    withdrawn_by_fiscal_year[hash[:accession_fiscal_year]][barcode] = hash
  else
    current_by_fiscal_year[hash[:accession_fiscal_year]] ||= {}
    current_by_fiscal_year[hash[:accession_fiscal_year]][barcode] = hash
  end
end; nil

File.open("#{output_dir}/recap_withdrawn_accessions.tsv", 'w') do |output|
  output.puts("Barcode\tCustomer Code\tAccession Date\tAccession FY\tWithdrawal Date\tWithdrawal FY")
  withdrawn_by_fiscal_year.each do |fy, items|
    items.each do |barcode, info|
      output.write("#{barcode}\t")
      output.write("#{info[:customer_code]}\t")
      output.write("#{info[:accession_date].strftime('%Y-%m-%d')}\t")
      output.write("#{info[:accession_fiscal_year]}\t")
      output.write("#{info[:withdrawal_date].strftime('%Y-%m-%d')}\t")
      output.puts(info[:withdrawal_fiscal_year])
    end
  end
end; nil
### Export 100,000 barcodes per file
current_by_fiscal_year.each do |fy, items|
  fnum = 1
  items.keys.each_slice(100_000) do |barcodes|
    File.open("#{output_dir}/recap_current_accessions_#{fy}_#{fnum}.tsv", 'w') do |output|
      output.puts('Barcode')
      barcodes.each { |barcode| output.puts(barcode) }
    end
    fnum += 1
  end
end; nil
