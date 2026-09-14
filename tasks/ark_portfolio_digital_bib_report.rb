# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'csv'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Step 1: Load in all portfolios that have ARKs linked to the bibs
### Analytics Report is called "ARK Portfolios"
bib_to_portfolios = {} # MMS ID is the key
CSV.open("#{input_dir}/ARK Portfolios.csv", 'r', headers: true, encoding: 'bom|utf-8') do |csv|
  csv.each do |row|
    mms_id = row['MMS Id']
    raw_url = row['Portfolio URL']
    raw_url ||= row['Portfolio Parser Parameters']
    raw_url ||= row['Portfolio Static URL (override)']
    raw_url ||= row['Portfolio Dynamic URL (override)']
    raw_url ||= row['Portfolio Static URL']
    raw_url ||= row['Portfolios Dynamic URL']
    url = raw_url.gsub(/^jkey=(.*)$/, '\1').gsub('https', 'http')
    portfolio_id = row['Portfolio Id']
    bib_to_portfolios[mms_id] ||= {}
    bib_to_portfolios[mms_id][url] ||= {}
    bib_to_portfolios[mms_id][url][portfolio_id] ||= row['PO Line Reference']
  end
end

### Step 2: Load in all digital inventory from Figgy
url = 'https://figgy.princeton.edu'
conn = api_conn(url)
auth_token = ENV.fetch('FIGGY_TOKEN', nil)
figgy_report = FiggyReport.new(conn: conn, auth_token: auth_token)
mms_to_objects = figgy_report.mms_hash
bib_to_digital = {}
mms_to_objects.each do |mms_id, objects|
  objects.each do |object|
    ark = object.marc_record['999']['c']
    url = "http://arks.princeton.edu/ark:/88435/#{ark}"
    bib_to_digital[mms_id] ||= []
    bib_to_digital[mms_id] << url
  end
end

### Step 3: Report out all URLs and where they are found
overlap_out = File.open("#{output_dir}/digital_inventory_portfolio_overlap.tsv", 'w')
done_urls = Set.new
overlap_out.puts("MMS ID\tURL\tSource")
bib_to_portfolios.each do |mms_id, portfolio_info|
  portfolio_urls = portfolio_info.keys
  digital_urls = bib_to_digital[mms_id]
  if digital_urls.nil?
    portfolio_urls.each do |url|
      overlap_out.puts("#{mms_id}\t#{url}\tPortfolio")
      done_urls << url
    end
  else
    (portfolio_urls - digital_urls).each do |url|
      overlap_out.puts("#{mms_id}\t#{url}\tPortfolio")
      done_urls << url
    end
    (portfolio_urls & digital_urls).each do |url|
      overlap_out.puts("#{mms_id}\t#{url}\tBoth")
      done_urls << url
    end
    (digital_urls - portfolio_urls).each do |url|
      overlap_out.puts("#{mms_id}\t#{url}\tDigital")
      done_urls << url
    end
  end
end
bib_to_digital.each do |mms_id, digital_urls|
  digital_urls.each do |url|
    next if done_urls.include?(url)

    overlap_out.puts("#{mms_id}\t#{url}\tDigital")
  end
end
overlap_out.close

### Step 4: Write out the portfolios that can be removed since there is an exact URL match to digital inventory
File.open("#{output_dir}/portfolios_with_matches_to_digital_inventory_arks.tsv", 'w') do |output|
  output.puts("MMS ID\tPortfolio ID\tPortfolio URL\tPOL")
  bib_to_portfolios.each do |mms_id, portfolio_info|
    digital_urls = bib_to_digital[mms_id]
    next unless digital_urls

    portfolio_info.each do |url, portfolios|
      portfolios.each do |portfolio_id, pol|
        line_reference = pol == '-1' ? nil : pol
        next unless digital_urls.include?(url)

        output.write("#{mms_id}\t")
        output.write("#{portfolio_id}\t")
        output.write("#{url}\t")
        output.puts(line_reference)
      end
    end
  end
end
