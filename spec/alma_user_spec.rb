# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::AlmaUser do
  subject(:alma_user) do
    described_class.new(contact_info: contact_info, name: name, group_status_barcode: group_status_barcode,
                        user_dates: user_dates, statistics: statistics)
  end

  context 'user with no statistical categories and multiple addresses' do
    let(:fixture) { 'alma_person_internal_no_statistic.json' }
    let(:contact_info) do
      {
        address: [
          AlmaAddress.new(
            lines: %w[street1],
            postcode_city_state_country: { postcode: '08111', city: 'Hiawatha', state: 'NJ', country: 'USA' },
            start_date: '2026-07-23Z',
            address_type: 'work',
            preferred: true
          ),
          AlmaAddress.new(
            lines: %w[street2],
            postcode_city_state_country: { postcode: '08112', city: 'Edison', state: 'NJ', country: 'USA' },
            start_date: '2026-07-23Z',
            address_type: 'school',
            preferred: false
          )
        ],
        email: [
          AlmaEmail.new(
            email_address: 'email@place.edu',
            email_type: 'personal',
            preferred: true
          )
        ],
        phone: [
          AlmaPhone.new(
            phone_number: '800-588-2300',
            phone_type: 'home',
            preferred: true
          )
        ]
      }
    end
    let(:name) { { first: 'Hoagy', middle: 'F.', last: 'Hero' } }
    let(:group_status_barcode) { { user_group: 'GST', status: 'ACTIVE', barcode: 'barcode' } }
    let(:user_dates) { { expiry: '2027-06-30Z', purge: '2034-06-30Z' } }
    let(:statistics) { [] }
    it 'matches reference user' do
      reference_user = stub_json_fixture(fixture: fixture)
      expect(JSON.parse(alma_user.to_json)).to eq reference_user
    end
  end

  context 'user with multiple statistical categories' do
    let(:fixture) { 'alma_person_internal_with_statistic.json' }
    let(:contact_info) do
      {
        address: [
          AlmaAddress.new(
            lines: %w[Street],
            postcode_city_state_country: { postcode: '08111', city: 'Hiawatha', state: 'NJ', country: 'USA' },
            start_date: '2026-07-23Z',
            address_type: 'school',
            preferred: true
          )
        ],
        email: [
          AlmaEmail.new(
            email_address: 'email@place.edu',
            email_type: 'personal',
            preferred: true
          )
        ],
        phone: [
          AlmaPhone.new(
            phone_number: '800-588-2300',
            phone_type: 'home',
            preferred: true
          )
        ]
      }
    end
    let(:name) { { first: 'Amanda', middle: '', last: 'Wolynn' } }
    let(:group_status_barcode) { { user_group: 'GST', status: 'ACTIVE', barcode: 'barcode' } }
    let(:user_dates) { { expiry: '2027-06-30Z', purge: '2034-06-30Z' } }
    let(:statistics) do
      [
        AlmaUserStatistic.new('PPPL'),
        AlmaUserStatistic.new('EM')
      ]
    end
    it 'matches reference user' do
      reference_user = stub_json_fixture(fixture: fixture)
      expect(JSON.parse(alma_user.to_json)).to eq reference_user
    end
  end
end
# rubocop:enable Metrics/BlockLength
