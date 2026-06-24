# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'csv'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Full report; this will serve as a baseline report
### Analytics report is called Aggregate Expenditures Periodicals
endowed_to_info = {}
csv = CSV.open("#{input_dir}/Aggregate Expenditures Periodicals.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  fund = row['Fund']
  fiscal_year = row['Fiscal Period Description']
  amount = BigDecimal(row['Transaction Amount (USD)'])
  endowed = fund[0] == 'E' ? 'endowed' : 'not_endowed'
  account = row['Reporting Code Description']
  endowed_to_info[endowed] ||= {}
  endowed_to_info[endowed][fund] ||= {}
  endowed_to_info[endowed][fund][account] ||= {}
  endowed_to_info[endowed][fund][account][fiscal_year] ||= BigDecimal('0')
  endowed_to_info[endowed][fund][account][fiscal_year] += amount
end
File.open("#{output_dir}/aggregated_expenditures_per_account.tsv", 'w') do |output|
  output.puts("Endowed Status\tFund\tAccount\tFiscal Period\tTotal Expenditure")
  endowed_to_info.each do |endowed_status, funds|
    funds.each do |fund, accounts|
      accounts.each do |account, fiscal_years|
        fiscal_years.each do |fiscal_year, amount|
          output.write("#{endowed_status}\t")
          output.write("#{fund}\t")
          output.write("#{account}\t")
          output.write("#{fiscal_year}\t")
          output.puts(amount.to_s('F'))
        end
      end
    end
  end
end

### Target reports: one where you exclude bibs with the following words:
###   magazine, newspaper, popular, entertainment
### One where you only include bibs with the following words:
###  business, professional, academic, technical

### Make a hash with MMS IDs as the keys and POLs as the values to serve as
###   a concordance for connecting to expenditures
### This is derived from the above Analytics report, modified to include MMS ID and POL
mms_to_pol = {}
CSV.open("#{input_dir}/periodical_expenditure_bib_pol.csv", 'r', headers: true, encoding: 'bom|utf-8').each do |row|
  pol = row['PO Line Reference']
  mms = row['MMS Id']
  mms_to_pol[mms] ||= []
  mms_to_pol[mms] << pol
end

all_mms_ids = Set.new(mms_to_pol.keys)

### Export the bibliographic records from Alma by making a set of the above MMS IDs
### Make 2 arrays of bibs based on the 2 criteria above
include_bibs = []
exclude_bibs = []
reader = MARC::XMLReader.new("#{input_dir}/bibs_associated_with_subscriptions.xml", parser: 'magic',
                                                                                    ignore_namespace: true)
reader.each do |record|
  next unless all_mms_ids.include?(record['001'].value)

  include = record.fields.any? do |field|
    (field.tag.to_i.between?(100, 499) || field.tag.to_i.between?(600, 899)) &&
      field.to_s.downcase =~ /business|professional|academic|technical/
  end
  exclude = record.fields.any? do |field|
    (field.tag.to_i.between?(100, 499) || field.tag.to_i.between?(600, 899)) &&
      field.to_s.downcase =~ /magazine|newspaper|popular|entertainment/
  end
  include_bibs << record['001'].value if include
  exclude_bibs << record['001'].value unless exclude
end

### Export the POLs associated with the above bibs to filter expenditures in Analytics
File.open("#{output_dir}/filtered_periodicals_pols_include_list.tsv", 'w') do |output|
  output.puts('PO Line Reference')
  include_bibs.each do |mms_id|
    pols = mms_to_pol[mms_id]
    next unless pols

    pols.each { |pol| output.puts(pol) }
  end
end

File.open("#{output_dir}/filtered_periodicals_pols_exclude_list.tsv", 'w') do |output|
  output.puts('PO Line Reference')
  exclude_bibs.each do |mms_id|
    pols = mms_to_pol[mms_id]
    next unless pols

    pols.each { |pol| output.puts(pol) }
  end
end

### Include list report
### Filter above Analytics query to only run on the POLs
include_endowed_to_info = {}
csv = CSV.open("#{input_dir}/aggregate_expenditures_include_list.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  chartstring = row['Fund External Id']
  fund = chartstring[6..10]
  fiscal_year = row['Fiscal Period Description']
  amount = BigDecimal(row['Transaction Amount (USD)'])
  endowed = fund[0] == 'E' ? 'endowed' : 'not_endowed'
  account = row['Reporting Code Description']
  include_endowed_to_info[endowed] ||= {}
  include_endowed_to_info[endowed][fund] ||= {}
  include_endowed_to_info[endowed][fund][account] ||= {}
  include_endowed_to_info[endowed][fund][account][fiscal_year] ||= BigDecimal('0')
  include_endowed_to_info[endowed][fund][account][fiscal_year] += amount
end
File.open("#{output_dir}/aggregated_expenditures_per_account_include_list.tsv", 'w') do |output|
  output.puts("Endowed Status\tFund\tAccount\tFiscal Period\tTotal Expenditure")
  include_endowed_to_info.each do |endowed_status, funds|
    funds.each do |fund, accounts|
      accounts.each do |account, fiscal_years|
        fiscal_years.each do |fiscal_year, amount|
          output.write("#{endowed_status}\t")
          output.write("#{fund}\t")
          output.write("#{account}\t")
          output.write("#{fiscal_year}\t")
          output.puts(amount.to_s('F'))
        end
      end
    end
  end
end

### Exclude list report
### Since the exclude list is too large, multiple Analytics exports will have to be performed;
###   Ensure each POL is only picked up once
exclude_endowed_to_info = {}
Dir.glob("#{input_dir}/aggregate_expenditures_exclude_*.csv").each do |file|
  csv = CSV.open(file, 'r', headers: true, encoding: 'bom|utf-8')
  csv.each do |row|
    chartstring = row['Fund External Id']
    fund = chartstring[6..10]
    fiscal_year = row['Fiscal Period Description']
    amount = BigDecimal(row['Transaction Amount (USD)'])
    endowed = fund[0] == 'E' ? 'endowed' : 'not_endowed'
    account = row['Reporting Code Description']
    pol = row['PO Line Reference']
    exclude_endowed_to_info[endowed] ||= {}
    exclude_endowed_to_info[endowed][fund] ||= {}
    exclude_endowed_to_info[endowed][fund][account] ||= {}
    exclude_endowed_to_info[endowed][fund][account][fiscal_year] ||= {}
    next if exclude_endowed_to_info[endowed][fund][account][fiscal_year][pol]

    exclude_endowed_to_info[endowed][fund][account][fiscal_year][pol] = amount
  end
end
File.open("#{output_dir}/aggregated_expenditures_per_account_exclude_list.tsv", 'w') do |output|
  output.puts("Endowed Status\tFund\tAccount\tFiscal Period\tTotal Expenditure")
  exclude_endowed_to_info.each do |endowed_status, funds|
    funds.each do |fund, accounts|
      accounts.each do |account, fiscal_years|
        fiscal_years.each do |fiscal_year, pols|
          total_amount = BigDecimal('0')
          pols.each_value { |amount| total_amount += amount }
          output.write("#{endowed_status}\t")
          output.write("#{fund}\t")
          output.write("#{account}\t")
          output.write("#{fiscal_year}\t")
          output.puts(total_amount.to_s('F'))
        end
      end
    end
  end
end
