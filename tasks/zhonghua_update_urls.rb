# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'csv'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### For each successful retrieved portfolio,
###   modify `static_url` to the new URL with `jkey=` added to the beginning
###   of each URL; also put new URL in `url`;
###   remove all other URLs from the portfolio;
###   make ['linking_details']['url_type_override']['value'] equal to '';
###   add the POL
def modify_portfolio(portfolio:, url:)
  portfolio['linking_details']['static_url'] = url
  portfolio['linking_details']['url_type_override']['value'] = ''
  portfolio['linking_details']['static_url_override'] = ''
  portfolio['linking_details']['url'] = url
  portfolio['linking_details']['url_type']['value'] = 'static'
  portfolio
end

### Step 1: Load in the portfolio IDs and URLs from a report
portfolio_to_url = {}
bib_portfolios = {}
csv = CSV.open("#{input_dir}/ZhonghuaPortfoliosList_Oct2025.csv", 'r', headers: true, encoding: 'bom|utf-8')
csv.each do |row|
  portfolio_id = row['Portfolio Id']
  url = row['New URL']
  mms_id = row['MMS Id']
  bib_portfolios[mms_id] ||= []
  bib_portfolios[mms_id] << portfolio_id
  portfolio_to_url[portfolio_id] = url
end

### Step 2: Iterate through all portfolio IDs; if the object ID appears in
###   a normalized version of the URL anywhere in the portfolio, update the
###   static URL to the new URL and remove all other URLs

### Retrieve each portfolio
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = LspData.api_conn(url)
api_key = ENV['ALMA_PROD_BIB_API_KEY']

get_responses = {} # hash of portfolio ID to response
bib_portfolios.each do |mms_id, portfolio_ids|
  portfolio_ids.each do |portfolio_id|
    next if get_responses[portfolio_id]

    response = ApiRetrievePortfolio.new(conn: conn, api_key: api_key, mms_id: mms_id, portfolio_id: portfolio_id)
    get_responses[portfolio_id] = response.response
  end
end

### Update the portfolios that were successfully retrieved
update_responses = {}
bib_portfolios.each do |mms_id, portfolio_ids|
  portfolio_ids.each do |portfolio_id|
    next if update_responses[portfolio_id]

    get_response = get_responses[portfolio_id]
    next unless get_response[:status] == 200

    url = portfolio_to_url[portfolio_id]
    original_portfolio = get_response[:body]
    portfolio = modify_portfolio(portfolio: original_portfolio, url: url)
    response = ApiUpdatePortfolio.new(mms_id: mms_id,
                                      portfolio_id: portfolio_id,
                                      api_key: api_key,
                                      conn: conn,
                                      portfolio: portfolio)
    update_responses[portfolio_id] = response.response
  end
end

### Step 3: Write out report
### When I check if there's a mapping, report out when there isn't one
### For each portfolio, put the status of each call
File.open("#{output_dir}/objects_updated_10-23-25.tsv", 'w') do |output|
  output.puts("New URL\tMMS ID\tPortfolio ID\tRetrieval Response\tUpdate Response")
  bib_portfolios.each do |mms_id, portfolios|
    portfolios.each do |portfolio_id|
      portfolio_url = portfolio_to_url[portfolio_id]
      retrieval = get_responses[portfolio_id]
      retrieval_status = retrieval ? retrieval[:status] : nil
      update = update_responses[portfolio_id]
      update_status = update ? update[:status] : nil
      output.write("#{portfolio_url}\t")
      output.write("#{mms_id}\t")
      output.write("#{portfolio_id}\t")
      output.write("#{retrieval_status}\t")
      output.puts(update_status)
    end
  end
end
