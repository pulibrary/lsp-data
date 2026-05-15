# frozen_string_literal: true

# Want report of all users that have had no requests in over seven years (since 1/1/2019)
require_relative '../lib/lsp-data'
require 'csv'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Get all information on users and requests
illiad_conn = ILLiad.new
loans_by_user = illiad_conn.all_loan_borrowing.group_by(&:username)
articles_by_user = illiad_conn.all_article_borrowing.group_by(&:username)
all_users = illiad_conn.all_users
date_cutoff = Time.new(2019, 1, 1, 0, 0, 0, '-05:00')

### Run Alma Analytics query to return all netIDs of users currently in Alma,
###   with Alma expiry and purge dates
alma_users = {} # netID is the key
CSV.open("#{input_dir}/all_alma_users_netids.csv", 'r', encoding: 'bom|utf-8', headers: true).each do |row|
  alma_users[row['Identifier Value']] = {
    status: row['Status'],
    expiry: row['Expiry Date'],
    purge: row['Purge Date']
  }
end

### If there is no loan or article request with a transaction date after 1/1/2019,
###   report the date of the last loan transaction and last article transaction
File.open("#{output_dir}/illiad_users_no_transactions_seven_years.tsv", 'w') do |output|
  output.write("Username\tLast Name\tFirst Name\tPatron Barcode\tStatus\tDepartment\t")
  output.write("NVTGC\tModification Date\tSite\tExpiration Date\tPrimary Identifier\t")
  output.puts("Alma Status\tAlma Expiry Date\tAlma Purge Date\tDate of Last Article Request\tDate of Last Loan")
  all_users.each do |user|
    loans = loans_by_user[user.username].to_a
    articles = articles_by_user[user.username].to_a
    alma_info = alma_users[user.username]
    alma_expiry = alma_info&.[](:expiry)
    alma_status = alma_info&.[](:status)
    alma_purge = alma_info&.[](:purge)
    if (loans.size + articles.size).zero?
      output.write("#{user.username}\t#{user.last_name}\t#{user.first_name}\t#{user.patron_barcode}\t")
      output.write("#{user.status}\t#{user.department}\t#{user.nvtgc}\t#{user.modification_date}\t#{user.site}\t")
      output.puts("#{user.expiration_date}\t#{user.primary_id}\t#{alma_status}\t#{alma_expiry}\t#{alma_purge}\t\t\t")
    else
      last_loan_date = loans.max { |a, b| a.transaction_date <=> b.transaction_date }&.transaction_date
      last_article_date = articles.max { |a, b| a.transaction_date <=> b.transaction_date }&.transaction_date
      next if last_loan_date && last_loan_date > date_cutoff
      next if last_article_date && last_article_date > date_cutoff

      output.write("#{user.username}\t#{user.last_name}\t#{user.first_name}\t#{user.patron_barcode}\t")
      output.write("#{user.status}\t#{user.department}\t#{user.nvtgc}\t#{user.modification_date}\t#{user.site}\t")
      output.write("#{user.expiration_date}\t#{user.primary_id}\t")
      output.puts("#{alma_status}\t#{alma_expiry}\t#{alma_purge}\t#{last_article_date}\t#{last_loan_date}")
    end
  end
end
