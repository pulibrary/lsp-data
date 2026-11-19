# frozen_string_literal: true

# What's needed is to create a SQL query that finds users who have a
#   last transaction type of Access Only Photo Card, then translate the data
#   into AlmaUser data.
# If a user lacks an email that matches the above criteria,
#   they should be reported out, and April will load them manually.
# Extra whitespace at the beginning and ending of each field should be trimmed.
# Notable transformations needed:
#   Category [mapped to statistical categories]
#   ID_1 [mapped to a note of type 'POPUP', prefixed with 'Access ID: ']
#   Institution [mapped to line1 of an Alternative address]
#   Expiry Date [9-1-27]
#   Purge Date [7 years from the date of generating the users]
#   Country [mapped to specific country values; default to USA]
#   Street1 [put Not given if blank]

require_relative '../lib/lsp-data'

### Map user categories to statistical categories; 'Other' will be disregarded
def category_to_statistic
  {
    'alumnus/a' => 'ALM',
    'faculty' => 'V Fac',
    'Staff' => 'V Stf',
    'Graduate' => 'V Student',
    'Undergraduate' => 'V Student'
  }
end

def institution_to_alternative_address(institution)
  postcode_city_state_country = { postcode: '', city: '', state: '', country: '' }
  AlmaAddress.new(lines: [institution],
                  postcode_city_state_country: postcode_city_state_country,
                  start_date: Time.new.strftime('%Y-%m-%dZ'),
                  address_type: 'alternative', preferred: false)
end

def info_to_user(contact_info:, barcode:, statistic:, note:)
  group_status_barcode = { user_group: 'ACCESS', status: 'ACTIVE', barcode: barcode }
  user = AlmaUser.new(contact_info: contact_info, group_status_barcode: group_status_barcode,
                      user_dates: { expiry: '2027-09-01Z', purge: '2033-09-01Z' },
                      statistics: statistic.nil? ? [] : [AlmaUserStatistic.new(statistic)],
                      notes: note.nil? ? [] : [AlmaUserNote.new(note_type: 'POPUP', note_text: "Access ID: #{note}")])
  JSON.parse(user.to_json)
end

UNWANTED_TOTAL_ELEMENTS = %w[
  gender
  password
  full_name
  created_by
  created_date
  last_modified_by
  last_modified_date
  user_title
  job_category
  job_description
  campus_code
  web_site_url
  cataloger_level
  preferred_language
  external_id
  force_password_change
  status_date
  user_role
  user_block
  pref_first_name
  pref_middle_name
  pref_last_name
  pref_name_suffix
].freeze

def remove_addres_nodes(user)
  user['contact_info']['address'].each do |address|
    address['country'].delete('desc')
    address.delete('address_note')
    address['address_type'].each { |element| element.delete('desc') }
  end
  user
end

def barcode_checksum(contact_info)
  contact_info[:address].map(&:to_h)
                        .dup
                        .each { |hash| hash.delete('country') }
                        .each { |hash| hash.delete('address_type') }
                        .map(&:values)
                        .join
                        .codepoints
                        .sum % 100
end

def remove_contact_info_nodes(user)
  remove_addres_nodes(user)
  user['contact_info']['email'].each do |email|
    email['email_type'].each { |element| element.delete('desc') }
  end
  user['contact_info']['phone'].each do |phone|
    phone.delete('preferred_sms')
    phone['phone_type'].each { |element| element.delete('desc') }
  end
  user
end

def remove_user_note_nodes(user)
  user['user_note'].delete_if { |note| note['note_text'] =~ /^Profile name/ }
  user['user_note'].each do |user_note|
    user_note['note_type'].delete('desc')
    %w[user_viewable popup_note created_by created_date].each { |element| user_note.delete(element) }
  end
  user
end

def remove_user_statistic_nodes(user)
  user['user_statistic'].each do |user_statistic|
    user_statistic['statistic_category'].delete('desc')
    user_statistic.delete('category_type')
  end
  user
end

def filter_user_elements(user)
  UNWANTED_TOTAL_ELEMENTS.each { |element| user.delete(element) }
  %w[status record_type user_group account_type].each { |element| user[element].delete('desc') }
  user['user_identifier'].each do |user_identifier|
    user_identifier['id_type'].delete('desc')
  end
  remove_contact_info_nodes(user)
  remove_user_note_nodes(user)
  remove_user_statistic_nodes(user)
  user
end

# rubocop:disable Metrics/MethodLength
def country_to_code
  {
    'ISRAEL' => 'ISR',
    'TURKEY' => 'TUR',
    'UNITED KINGDOM' => 'GBR',
    'NEW ZEALAND' => 'NZL',
    'FRANCE' => 'FRA',
    'CANADA' => 'CAN',
    'GREECE' => 'GRC',
    'GERMANY' => 'DEU',
    'SINGAPORE' => 'SGP',
    'MEXICO' => 'MEX',
    'DENMARK' => 'DNK',
    'CHINA' => 'CHN',
    'TAIWAN' => 'TWN',
    'INDIA' => 'IND',
    'JAMAICA' => 'JAM',
    'BRAZIL' => 'BRA',
    'FINLAND' => 'FIN',
    'UNITED STATES' => 'USA',
    'POLAND' => 'POL',
    'WALES' => 'GBR',
    'ARGENTINA' => 'ARG',
    'KENYA' => 'KEN',
    'AUSTRALIA' => 'AUS',
    'HUNGARY' => 'HUN',
    'THAILAND' => 'THA',
    'AZERBAIJAN' => 'AZE',
    'PERU' => 'PER',
    'PORTUGAL' => 'PRT',
    'SWITZERLAND' => 'CHE',
    'TURKIYE' => 'TUR',
    'UK' => 'GBR',
    'South Korea' => 'KOR',
    'AUSTRIA' => 'AUT'
  }
end
# rubocop:enable Metrics/MethodLength

# rubocop:disable Metrics/MethodLength
def access_query
  %(
    SELECT
      a.Patron_num,
      a.[First],
      a.Initial,
      a.[Last],
      a.Category,
      REPLACE(REPLACE(a.Phone, CHAR(13), ''), CHAR(10), '') Phone,
      a.Email,
      a.institution,
      a.ZIP1,
      REPLACE(REPLACE(a.Street1, CHAR(13), ''), CHAR(10), '') Street1,
      a.City1,
      a.Country1,
      a.State1,
      a.ID_1,
      a.ID_1_Expires,
      a.Note,
      t.[Type],
      t.Trans_note
    FROM Applicants a
      INNER JOIN (
        SELECT
          Patron_num,
          MAX(idTransaction) trans_num
        FROM Transactions
        GROUP BY
          Patron_num
        ) max_transact ON a.Patron_num = max_transact.Patron_num
      INNER JOIN Transactions t ON t.idTransaction = max_transact.trans_num
    WHERE t.[Type] = 'Access Only Photo Card' AND t.[Date] > '2021-01-01'
    GROUP BY
      a.Patron_num,
      a.[First],
      a.Initial,
      a.[Last],
      a.Category,
      Phone,
      a.Email,
      a.institution,
      a.ZIP1,
      Street1,
      a.City1,
      a.Country1,
      a.State1,
      a.ID_1,
      a.ID_1_Expires,
      a.Note,
      t.[Type],
      t.Trans_note
  )
end
# rubocop:enable Metrics/MethodLength

output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Execute the query; iterate through the results and map them to Alma users
username = ENV.fetch('ACCESS_OFFICE_USER', nil)
password = ENV.fetch('ACCESS_OFFICE_PASSWORD', nil)
host = ENV.fetch('ACCESS_OFFICE_HOST', nil)
database = ENV.fetch('ACCESS_OFFICE_DATABASE', nil)

conn = TinyTds::Client.new(username: username, password: password, host: host, database: database)
results = conn.execute(access_query)
users = []
users_no_email = [] # will report to the stakeholder without generating a report
results.each do |result|
  email_address = result['Email']&.strip
  name = { first: result['First'].to_s.strip, middle: result['Initial'].to_s.strip, last: result['Last'].to_s.strip }
  users_no_email << name unless email_address
  next unless email_address

  alternate_address = institution_to_alternative_address(result['institution'].strip)
  country = country_to_code[result['Country1']&.strip] || 'USA'
  line1 = result['Street1'] ? result['Street1'].strip : 'Not given'
  postcode_city_state_country = { postcode: result['ZIP1'].to_s.strip, city: result['City1'].to_s.strip,
                                  state: result['State1'].to_s.strip, country: country }
  home_address = AlmaAddress.new(lines: [line1],
                                 postcode_city_state_country: postcode_city_state_country,
                                 start_date: Time.new.strftime('%Y-%m-%dZ'), address_type: 'home', preferred: false)
  statistic = category_to_statistic[result['Category']]
  email = AlmaEmail.new(email_address: email_address, email_type: 'personal', preferred: true)
  phone = result['Phone']&.strip
  note = result['ID_1']&.strip
  contact_info = {
    address: [home_address, alternate_address],
    email: [email],
    phone: phone ? [AlmaPhone.new(phone_number: phone, phone_type: 'mobile', preferred: true)] : [],
    first: name[:first], middle: name[:middle], last: name[:last]
  }
  barcode_checksum = barcode_checksum(contact_info)
  barcode = "#{name[:last][0..4]}#{name[:first][0..4]}#{barcode_checksum}".downcase # not going to be used in Alma
  users << info_to_user(contact_info: contact_info, barcode: barcode, statistic: statistic, note: note)
end

### Output the users for final review
header_row = "Primary Identifier\tBarcode\tLast Name\tFirst Name\tMiddle Initial\t".dup
header_row << "Statistical Category\tAddress Line1\tCity\tState\tCountry\tPostal Code\tInstitution\t"
header_row << "Email\tPhone\tNote"
output = File.open("#{output_dir}/access_office_users_final_report.tsv", 'w')
output.puts(header_row)
users.each do |user|
  category = user['user_statistic'].empty? ? '' : user['user_statistic'].first['statistic_category']['value']
  main_address = user['contact_info']['address'].find { |address| address['address_type'].first['value'] == 'home' }
  institution = user['contact_info']['address'].find do |address|
    address['address_type'].first['value'] == 'alternative'
  end
  note = user['user_note'].first
  phone = user['contact_info']['phone'].first
  output.write("#{user['primary_id']}\t#{user['user_identifier'].first['value']}\t")
  output.write("#{user['last_name']}\t#{user['first_name']}\t#{user['middle_name']}\t")
  output.write("#{category}\t")
  output.write("#{main_address['line1']}\t#{main_address['city']}\t#{main_address['state_province']}\t")
  output.write("#{main_address['country']['value']}\t")
  output.write("#{main_address['postal_code']}\t")
  output.write("#{institution['line1']}\t")
  output.write("#{user['contact_info']['email'].first['email_address']}\t")
  if phone.instance_of?(Hash)
    output.write("#{phone['phone_number']}\t")
  else
    output.write("\t")
  end
  if note.instance_of?(Hash)
    output.puts(note['note_text'])
  else
    output.puts('')
  end
end
output.close

### Load the users into Alma and store the records created for a final report
###   of what was loaded
api_key = ENV.fetch('ALMA_SANDBOX_USER_API_KEY', nil)
url = 'https://api-na.hosted.exlibrisgroup.com'
conn = api_conn(url)
user_results = {} # primary_id will be the key
users.each do |user|
  next if user_results[user['primary_id']]

  result = AlmaCreateUser.new(conn: conn, api_key: api_key, user: user)
  user_results[user['primary_id']] = result.response
end

### Assess if any user details are different in the output than the input
users_with_discrepancy = {}
users.each do |before|
  primary_id = before['primary_id']
  before_filtered = filter_user_elements(before.dup)
  result = user_results[primary_id]
  after = result[:body]
  after_filtered = filter_user_elements(after.dup)
  before_filtered['contact_info']['address'].sort_by! { |address| address['line1'] }
  after_filtered['contact_info']['address'].sort_by! { |address| address['line1'] }
  unless before_filtered.eql?(after_filtered)
    users_with_discrepancy[primary_id] =
      { before: before_filtered, after: after_filtered }
  end
end

### Produce report of what was loaded
header_row = "Primary Identifier\tBarcode\tLast Name\tFirst Name\tMiddle Initial\t".dup
header_row << "Statistical Category\tAddress Line1\tCity\tState\tCountry\tPostal Code\tInstitution\t"
header_row << "Email\tPhone\tNote\tUser Group"
failed_user_output = File.open("#{output_dir}/access_office_users_failed_loading.tsv", 'w')
failed_user_output.puts("Primary ID\tStatus Code\tError Message")
output = File.open("#{output_dir}/access_office_users_loaded_into_alma.tsv", 'w')
output.puts(header_row)
user_results.each do |primary_id, info|
  if info[:status] == 200
    user = info[:body]
    category = user['user_statistic'].empty? ? '' : user['user_statistic'].first['statistic_category']['value']
    main_address = user['contact_info']['address'].find { |address| address['address_type'].first['value'] == 'home' }
    institution = user['contact_info']['address'].find do |address|
      address['address_type'].first['value'] == 'alternative'
    end
    note = user['user_note'].first
    phone = user['contact_info']['phone'].first
    output.write("#{user['primary_id']}\t#{user['user_identifier'].first['value']}\t")
    output.write("#{user['last_name']}\t#{user['first_name']}\t#{user['middle_name']}\t")
    output.write("#{category}\t")
    output.write("#{main_address['line1']}\t#{main_address['city']}\t#{main_address['state_province']}\t")
    output.write("#{main_address['country']['value']}\t")
    output.write("#{main_address['postal_code']}\t#{institution['line1']}\t")
    output.write("#{user['contact_info']['email'].first['email_address']}\t")
    output.write(phone['phone_number']) if phone.instance_of?(Hash)
    output.write("\t")
    output.write(note['note_text']) if note.instance_of?(Hash)
    output.write("\t")
    output.puts('ACCESS')
  else
    failed_user_output.puts("#{primary_id}\t#{info[:status]}\t#{info[:body]}")
  end
end
output.close
failed_user_output.close
