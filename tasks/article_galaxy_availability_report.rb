# frozen_string_literal: true

### - [ ] Coverage for each of the ISSNs listed in the spreadsheet is retrieved from the associated portfolios
### - [ ] Coverage from multiple portfolios is combined to show the full span from all services
require_relative './../lib/lsp-data'
require 'csv'

def portfolio_info_from_f951(field:, mms_id:, match_type:)
  status = field['a']
  id = field['0']
  coverage_statement = field['k']
  { status: status,
    id: id,
    coverage_statement: coverage_statement,
    mms_id: mms_id,
    match_type: match_type }
end

def get_portfolios(record)
  record.fields('951').select do |field|
    field['0'] =~ /6421$/ && field['a'] == 'Available'
  end
end

def get_coverage_from_portfolios(portfolios:, mms_id:, match_type:)
  coverage = []
  portfolios.each do |portfolio|
    info = portfolio_info_from_f951(field: portfolio, mms_id: mms_id, match_type: match_type)
    coverage << info
  end
  coverage
end

def expanded_issns(record)
  issn = []
  issn_fields = record.fields(%w[775 776 777 786 800 811 830])
  issn_fields.each do |field|
    field.subfields.each do |subfield|
      next unless subfield.code == 'x'

      value = issn_normalize(subfield.value)
      issn << value if value
    end
  end
  issn.uniq
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
issn_hash = {}
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    issns = issns(record)
    matches = all_issns & issns
    expanded_issns = expanded_issns(record)
    expanded_matches = all_issns & expanded_issns
    next unless matches.size.positive? || expanded_matches.size.positive?

    portfolios = get_portfolios(record)
    next if portfolios.empty?

    mms_id = record['001'].value
    matches.each do |issn|
      issn_hash[issn] ||= []
      issn_hash[issn] += get_coverage_from_portfolios(portfolios: portfolios,
                                                      mms_id: mms_id,
                                                      match_type: 'standard')
    end
    expanded_matches.each do |issn|
      issn_hash[issn] ||= []
      issn_hash[issn] += get_coverage_from_portfolios(portfolios: portfolios,
                                                      mms_id: mms_id,
                                                      match_type: 'expanded')
    end
  end
end

### Write out report of active portfolios with their coverage;
File.open("#{output_dir}/ags_availability_report.tsv", 'w') do |output|
  output.puts("ISSN\tTitle\tPublisher\tMatch Type\tMMS ID\tPortfolio ID\tCoverage Statement")
  title_lines.each do |line|
    coverage = issn_hash[line[:issn]]
    if coverage
      coverage.each do |statement|
        output.write("#{line[:issn]}\t")
        output.write("#{line[:title]}\t")
        output.write("#{line[:publisher]}\t")
        output.write("#{statement[:match_type]}\t")
        output.write("#{statement[:mms_id]}\t")
        output.write("#{statement[:id]}\t")
        output.puts(statement[:coverage_statement])
      end
    else
      output.write("#{line[:issn]}\t")
      output.write("#{line[:title]}\t")
      output.write("#{line[:publisher]}\t")
      output.puts("\t\t\t")
    end
  end
end
