# frozen_string_literal: true

### - [ ] Coverage for each of the ISSNs listed in the spreadsheet is retrieved from the associated portfolios
### - [ ] Coverage from multiple portfolios is combined to show the full span from all services
require_relative './../lib/lsp-data'
require 'csv'

def portfolio_info_from_f951(field:, mms_id:)
  status = field['a']
  id = field['0']
  coverage_statement = field['k']
  { status: status, id: id, coverage_statement: coverage_statement, mms_id: mms_id }
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

title_lines = []
csv = CSV.open("#{input_dir}/ags_titles.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  hash = {}
  hash[:title] = row['Title']
  hash[:issn] = row['ISSN']
  hash[:publisher] = row['Publisher']
  title_lines << hash
end
all_issns = title_lines.map { |line| line[:issn] }.uniq

### Find all portfolios associated with bibs that have the above ISSNs
###   Search in 022$a, 022$l, and 023$a
###   Coverage info is found in the full dump in 951 field;
###   951 has ID in $0, status in $a, and coverage statement in $k;
issn_coverage_hash = {}
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    issns = issns(record)
    matches = all_issns & issns
    next unless matches.size.positive?

    portfolios = record.fields('951').select do |field|
      field['0'] =~ /6421$/ && field['a'] == 'Available'
    end
    next if portfolios.empty?

    mms_id = record['001'].value
    matches.each do |issn|
      issn_coverage_hash[issn] ||= []
      portfolios.each do |portfolio|
        info = portfolio_info_from_f951(field: portfolio, mms_id: mms_id)
        issn_coverage_hash[issn] << info
      end
    end
  end
end

### Write our report of active portfolios with their coverage;
###   In this case, there are no multiple portfolio matches
File.open("#{output_dir}/ags_availability_report.tsv", 'w') do |output|
  output.puts("ISSN\tTitle\tPublisher\tMMS ID\tPortfolio ID\tCoverage Statement")
  title_lines.each do |line|
    coverage = issn_coverage_hash[line[:issn]]
    output.write("#{line[:issn]}\t")
    output.write("#{line[:title]}\t")
    output.write("#{line[:publisher]}\t")
    if coverage
      statement = coverage.first
      output.write("#{statement[:mms_id]}\t")
      output.write("#{statement[:id]}\t")
      output.puts(statement[:coverage_statement])
    else
      output.puts("\t\t")
    end
  end
end
