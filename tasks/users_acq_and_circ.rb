# frozen_string_literal: true

### Find all staff that have a combination of Circulation Desk Operator/Limited or
###   Circulation Desk Manager and an Acquisitions role:
###   Receiving Operator/Limited, Purchasing Operator/Extended, Purchasing Manager

require_relative '../lib/lsp-data'
require 'csv'

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

users = {} # primary identifier is key
CSV.open("#{input_dir}/All Users With Roles Other Than Patron.csv", headers: true, encoding: 'bom|utf-8').each do |row|
  primary_id = row['Primary Identifier']
  users[primary_id] ||= {
    last: row['Last Name'], first: row['First Name'],
    status: row['Status'], expiry: row['Expiry Date'], user_group: row['User Group'], roles: []
  }
  users[primary_id][:roles] << {
    type: row['Role Type'], status: row['Role Status'],
    status_date: row['Role Status Date'],
    scope: row['Role Scope'], role_expiry: row['Role Expiry Date']
  }
end

### Report out all inactive users that have roles other than Patron
File.open("#{output_dir}/inactive_users_with_roles.tsv", 'w') do |output|
  output.write("Primary ID\tLast Name\tFirst Name\tFull Name\tUser Expiry Date\tUser Group\t")
  output.puts("Role\tRole Status\tRole Status Date\tRole Scope\tRole Expiry Date")
  users.reject { |_id, info| info[:status] == 'Active' }.each do |id, info|
    info[:roles].each do |role|
      output.write("#{id}\t#{info[:last]}\t#{info[:first]}\t#{info[:last]}, #{info[:first]}\t")
      output.write("#{info[:expiry]}\t#{info[:user_group]}\t#{role[:type]}\t#{role[:status]}\t")
      output.puts("#{role[:status_date]}\t#{role[:scope]}\t#{role[:role_expiry]}")
    end
  end
end

### Report out all active users that have Acq and Circ roles
circ_roles = ['Circulation Desk Operator', 'Circulation Desk Operator - Limited', 'Circulation Desk Manager']
acq_roles = [
  'Receiving Operator', 'Receiving Operator Limited', 'Purchasing Operator',
  'Purchasing Operator Extended', 'Purchasing Manager', 'Acquisitions Administrator'
]
File.open("#{output_dir}/active_users_with_acq_and_circ_roles.tsv", 'w') do |output|
  output.write("Primary ID\tLast Name\tFirst Name\tFull Name\tUser Expiry Date\tUser Group\t")
  output.puts("Role Category\tRole\tRole Status\tRole Status Date\tRole Scope\tRole Expiry Date")
  users.each do |id, info|
    circ = info[:roles].select { |role| circ_roles.include?(role[:type]) }
    acq = info[:roles].select { |role| acq_roles.include?(role[:type]) }
    other = info[:roles].reject { |role| (circ + acq).include?(role) }
    next unless circ.size.positive? && acq.size.positive?
    next unless info[:status] == 'Active'

    circ.each do |role|
      output.write("#{id}\t#{info[:last]}\t#{info[:first]}\t#{info[:last]}, #{info[:first]}\t#{info[:expiry]}\t")
      output.write("#{info[:user_group]}\tCirculation\t#{role[:type]}\t#{role[:status]}\t")
      output.puts("#{role[:status_date]}\t#{role[:scope]}\t#{role[:role_expiry]}")
    end
    acq.each do |role|
      output.write("#{id}\t#{info[:last]}\t#{info[:first]}\t#{info[:last]}, #{info[:first]}\t#{info[:expiry]}\t")
      output.write("#{info[:user_group]}\tAcquisitions\t#{role[:type]}\t#{role[:status]}\t")
      output.puts("#{role[:status_date]}\t#{role[:scope]}\t#{role[:role_expiry]}")
    end
    other.each do |role|
      output.write("#{id}\t#{info[:last]}\t#{info[:first]}\t#{info[:last]}, #{info[:first]}\t#{info[:expiry]}\t")
      output.write("#{info[:user_group]}\tOther\t#{role[:type]}\t#{role[:status]}\t")
      output.puts("#{role[:status_date]}\t#{role[:scope]}\t#{role[:role_expiry]}")
    end
  end
end
