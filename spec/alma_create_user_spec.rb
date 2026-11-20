# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::AlmaCreateUser do
  subject(:created_user) do
    described_class.new(conn: conn,
                        api_key: 'apikey',
                        user: user)
  end

  let(:conn) { api_conn('https://api-na.exlibrisgroup.com') }
  let(:filename) { 'alma_person_internal_with_statistic.json' }
  let(:file) { File.open("#{FIXTURE_DIR}/#{filename}") }
  let(:user_json) { JSON.parse(File.read(file)) }
  let(:address_block) { user_json['contact_info']['address'].first }
  let(:address) do
    AlmaAddress.new(lines: [address_block['line1']],
                    postcode_city_state_country: {
                      postcode: address_block['postal_code'],
                      city: address_block['city'],
                      state: address_block['state_province'],
                      country: address_block['country']['value']
                    },
                    start_date: address_block['start_date'],
                    address_type: address_block['address_type'].first['value'],
                    preferred: address_block['preferred'])
  end
  let(:phone_block) { user_json['contact_info']['phone'].first }
  let(:phone) do
    AlmaPhone.new(phone_number: phone_block['phone_number'],
                  phone_type: phone_block['phone_type'].first['value'],
                  preferred: phone_block['preferred'])
  end
  let(:email_block) { user_json['contact_info']['email'].first }
  let(:email) do
    AlmaEmail.new(email_address: email_block['email_address'],
                  email_type: email_block['email_type'].first['value'],
                  preferred: email_block['preferred'])
  end
  let(:contact_info) do
    {
      address: [address], phone: [phone], email: [email],
      first: user_json['first_name'], middle: user_json['middle_name'], last: user_json['last_name']
    }
  end
  let(:statistic) { user_json['user_statistic'].first['statistic_category']['value'] }
  let(:group_status_barcode) do
    {
      user_group: user_json['user_group']['value'],
      status: user_json['status']['value'],
      barcode: user_json['user_identifier'].first['value']
    }
  end
  let(:user_dates) { { expiry: user_json['expiry_date'], purge: user_json['purge_date'] } }
  let(:user) do
    AlmaUser.new(contact_info: contact_info,
                 group_status_barcode: group_status_barcode,
                 user_dates: user_dates,
                 statistics: [AlmaUserStatistic.new(statistic)])
  end

  context 'User is successfully loaded' do
    let(:status) { 200 }
    let(:fixture) { 'alma_person_internal_with_statistic.json' }
    it 'returns a created user in response body' do
      stub_create_user_response(user: user, fixture: fixture, status: status)
      expect(created_user.response[:body]['primary_id']).to eq user_json['primary_id']
    end
  end

  context 'API call returns an error' do
    let(:status) { 400 }
    let(:fixture) { 'alma_create_user_error.json' }
    it 'returns errors in response body' do
      stub_create_user_response(user: user, fixture: fixture, status: status)
      expect(created_user.response[:body]['errorsExist']).to be true
    end
  end
end
# rubocop:enable Metrics/BlockLength
