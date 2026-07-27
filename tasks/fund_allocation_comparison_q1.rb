# frozen_string_literal: true

### This comparison is to compare PeopleSoft transactions
###   with an Origin other than Library or Concur with Alma allocations
### When reconciling transactions in the first quarter, you must also look for
###   PeopleSoft transactions in the last period of the last fiscal year in Alma
require_relative '../lib/lsp-data'
require 'csv'

def invalid_peoplesoft_transaction?(row, ids_to_skip)
  (row['Transaction Origin'] == 'Library' && row['Transaction'] == 'Voucher') ||
    (row['Transaction Origin'] == 'Concur' && row['Transaction'] == 'Departmental Purchasing Card') ||
    ids_to_skip.include?(peoplesoft_transaction_reference(row))
end

def peoplesoft_transaction_reference(row)
  row['Transaction ID'].strip.empty? ? row['Journal ID'] : row['Transaction ID']
end

def peoplesoft_chartstring(row)
  [row['Department'], row['Fund'], row['Program']].join('|').gsub(%r{\|N/A$}, '')
end

def peoplesoft_transaction_note(row)
  [
    row['Transaction Origin'],
    row['Description 1'],
    DateTime.strptime(row['Ledger Date'], '%m/%d/%Y').strftime('%m/%d/%Y')
  ].join(' | ')
end

def peoplesoft_info(row)
  {
    transaction_reference: peoplesoft_transaction_reference(row),
    chartstring: peoplesoft_chartstring(row),
    note: peoplesoft_transaction_note(row),
    amount: BigDecimal(row['Actuals'].gsub(',', '')) * -1
  }
end

### Export Ledger Detail YTD
###   First as Excel Data; then export from Excel as a UTF-8 CSV
### Group transactions by chartstring, then by Alma Transaction ID, then by the Alma transaction note
input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)
peoplesoft_transactions_to_skip = ENV.fetch('PEOPLESOFT_TO_SKIP', '').split(',')
peoplesoft_by_chartstring = {}
CSV.open("#{input_dir}/ledger_detail.csv", headers: true, encoding: 'bom|utf-8').each do |row|
  next if invalid_peoplesoft_transaction?(row, peoplesoft_transactions_to_skip)

  info = peoplesoft_info(row)
  peoplesoft_by_chartstring[info[:chartstring]] ||= {}
  peoplesoft_by_chartstring[info[:chartstring]][info[:transaction_reference]] ||= {}
  peoplesoft_by_chartstring[info[:chartstring]][info[:transaction_reference]][info[:note]] ||= {}
  peoplesoft_by_chartstring[info[:chartstring]][info[:transaction_reference]][info[:note]][:amount] ||= BigDecimal('0')
  peoplesoft_by_chartstring[info[:chartstring]][info[:transaction_reference]][info[:note]][:amount] += info[:amount]
end

### Retrieve all active allocated funds via API
api_key = ENV.fetch('ALMA_PROD_ACQ_API_KEY', nil)
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = LspData.api_conn(url)
all_funds = ApiRetrieveFunds.new(api_key: api_key, conn: conn).allocated_funds
# for the first 2 quarters of a fiscal year, the previous fiscal year is the current year
previous_fy = Time.now.strftime('%y')
previous_funds = ApiRetrieveFunds.new(api_key: api_key, conn: conn, status: 'INACTIVE',
                                      fiscal_period: previous_fy).allocated_funds
alma_transactions_to_skip = ENV.fetch('ALMA_TRANSACTIONS_TO_SKIP', '').split(',')

### Retrieve all Alma allocations by fund via API; group by transaction_reference_number and transaction_note;
###   don't include transactions with no reference number, as these are rollover amounts
alma_by_chartstring = {}
all_funds.each do |fund|
  all_transactions = ApiRetrieveFundTransactions.new(api_key: api_key, conn: conn, fund_id: fund.id).allocations
  all_transactions.group_by(&:transaction_reference_number).each do |transaction_reference, info|
    next if transaction_reference.nil? || alma_transactions_to_skip.include?(transaction_reference)

    info.group_by(&:transaction_note).each do |note, transactions|
      amount = transactions.map(&:amount).sum
      alma_by_chartstring[fund.chartstring] ||= {}
      alma_by_chartstring[fund.chartstring][transaction_reference] ||= {}
      alma_by_chartstring[fund.chartstring][transaction_reference][note] ||= {}
      alma_by_chartstring[fund.chartstring][transaction_reference][note][:amount] ||= BigDecimal('0')
      alma_by_chartstring[fund.chartstring][transaction_reference][note][:amount] += amount
    end
  end
end
previous_funds.each do |fund|
  all_transactions = ApiRetrieveFundTransactions.new(api_key: api_key, conn: conn, fund_id: fund.id).allocations
  all_transactions.group_by(&:transaction_reference_number).each do |transaction_reference, info|
    next if transaction_reference.nil? || alma_transactions_to_skip.include?(transaction_reference)

    info.group_by(&:transaction_note).each do |note, transactions|
      amount = transactions.map(&:amount).sum
      alma_by_chartstring[fund.chartstring] ||= {}
      alma_by_chartstring[fund.chartstring][transaction_reference] ||= {}
      alma_by_chartstring[fund.chartstring][transaction_reference][note] ||= {}
      alma_by_chartstring[fund.chartstring][transaction_reference][note][:amount] ||= BigDecimal('0')
      alma_by_chartstring[fund.chartstring][transaction_reference][note][:amount] += amount
    end
  end
end
### Find chartstrings that are only in one system and report out all transactions
file_date = Time.now.strftime('%Y-%m-%d')
alma_chartstrings = all_funds.map(&:chartstring)
File.open("#{output_dir}/allocation_chartstrings_in_one_system_#{file_date}.tsv", 'w') do |output|
  output.puts("Chartstring\tSystem\tTransaction Reference\tTransaction Note\tAmount")
  alma_by_chartstring.each do |chartstring, transactions|
    next if peoplesoft_by_chartstring[chartstring]

    transactions.each do |transaction_id, notes|
      notes.each do |note, transaction|
        output.puts("#{chartstring}\tAlma\t#{transaction_id}\t#{note}\t#{transaction[:amount].to_s('F')}")
      end
    end
  end
  peoplesoft_by_chartstring.each do |chartstring, transactions|
    next if alma_chartstrings.include?(chartstring)

    transactions.each do |transaction_id, notes|
      notes.each do |note, transaction|
        output.puts("#{chartstring}\tPeopleSoft\t#{transaction_id}\t#{note}\t#{transaction[:amount].to_s('F')}")
      end
    end
  end
end

### Find chartstrings with differing numbers of transactions or differing amounts,
###   and report out any discrepancies
alma_only_transactions_by_chartstring = {}
peoplesoft_only_transactions_by_chartstring = {}
common_transactions_by_chartstring = {}
alma_by_chartstring.each do |chartstring, alma|
  peoplesoft = peoplesoft_by_chartstring[chartstring]
  next if peoplesoft.nil?

  alma_only = alma.keys - peoplesoft.keys # transaction reference numbers
  alma_only.each do |trans_id|
    alma_only_transactions_by_chartstring[chartstring] ||= {}
    alma_only_transactions_by_chartstring[chartstring][trans_id] = alma[trans_id]
  end
  peoplesoft_only = peoplesoft.keys - alma.keys # transaction reference numbers
  peoplesoft_only.each do |trans_id|
    peoplesoft_only_transactions_by_chartstring[chartstring] ||= {}
    peoplesoft_only_transactions_by_chartstring[chartstring][trans_id] = peoplesoft[trans_id]
  end
  alma.keys.intersection(peoplesoft.keys).each do |trans_id|
    alma_transactions = alma[trans_id]
    peoplesoft_transactions = peoplesoft[trans_id]
    common_transactions_by_chartstring[chartstring] ||= {}
    common_transactions_by_chartstring[chartstring][trans_id] ||= {}
    common_transactions_by_chartstring[chartstring][trans_id][:alma] = alma_transactions
    common_transactions_by_chartstring[chartstring][trans_id][:peoplesoft] = peoplesoft_transactions
  end
end

fiscal_period = ENV.fetch('CURRENT_FISCAL_PERIOD', '26')
output = File.open("#{output_dir}/transaction_discrepancies_#{file_date}.tsv", 'w')
output.puts("Chartstring\tSystem\tTransaction Reference\tTransaction Note\tAmount")
trans_out = CSV.open("/Users/mzelesky/Downloads/missing_allocations_#{file_date}.csv", 'w')
trans_out << %w[FUND_EXTERNAL_ID FISCAL_PERIOD_ID AMOUNT TRANSACTION_REFERENCE_NUMBER TRANSACTION_NOTE]
### Write out the transaction reference numbers that are only in one system
alma_only_transactions_by_chartstring.each do |chartstring, transactions|
  transactions.each do |transaction_reference, notes|
    notes.each do |note, transaction|
      output.puts("#{chartstring}\tAlma\t#{transaction_reference}\t#{note}\t#{transaction[:amount].to_s('F')}")
    end
  end
end
peoplesoft_only_transactions_by_chartstring.each do |chartstring, transactions|
  transactions.each do |transaction_reference, notes|
    notes.each do |note, transaction|
      output.puts("#{chartstring}\tPeopleSoft\t#{transaction_reference}\t#{note}\t#{transaction[:amount].to_s('F')}")
      trans_out << [chartstring, fiscal_period, transaction[:amount].to_s('F'), transaction_reference, note]
    end
  end
end
### Write out the transactions that have a discrepancy in the amount of transactions or the amount of money
common_transactions_by_chartstring.each do |chartstring, transactions|
  transactions.each do |transaction_ref, systems|
    alma_only = systems[:alma].reject { |note, _transaction| systems[:peoplesoft][note] }
    peoplesoft_only = systems[:peoplesoft].reject { |note, _transaction| systems[:alma][note] }
    systems[:alma].keys.intersection(systems[:peoplesoft].keys).each do |note|
      alma_transaction = systems[:alma][note]
      ps_transaction = systems[:peoplesoft][note]
      if alma_transaction[:amount] != ps_transaction[:amount]
        output.puts("#{chartstring}\tAlma\t#{transaction_ref}\t#{note}\t#{alma_transaction[:amount].to_s('F')}")
        output.puts("#{chartstring}\tPeopleSoft\t#{transaction_ref}\t#{note}\t#{ps_transaction[:amount].to_s('F')}")
      end
    end
    alma_only.each do |note, transaction|
      output.puts("#{chartstring}\tAlma\t#{transaction_ref}\t#{note}\t#{transaction[:amount].to_s('F')}")
    end
    peoplesoft_only.each do |note, transaction|
      output.puts("#{chartstring}\tPeopleSoft\t#{transaction_ref}\t#{note}\t#{transaction[:amount].to_s('F')}")
      trans_out << [chartstring, fiscal_period, transaction[:amount].to_s('F'), transaction_ref, note]
    end
  end
end
output.close
trans_out.close
