# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::AlmaAddress do
  subject(:alma_address) do
    described_class.new(lines: lines,
                        postcode_city_state_country: postcode_city_state_country,
                        start_date: start_date,
                        address_type: address_type,
                        preferred: preferred)
  end

  context 'preferred work address with 6 address lines' do
    let(:lines) { %w[street apartment suite room bed bunk] }
    let(:postcode_city_state_country) { { postcode: '90210', city: 'Schoenhut', state: 'PA', country: 'USA' } }
    let(:start_date) { '2026-11-01Z' }
    let(:address_type) { 'work' }
    let(:preferred) { true }
    it 'returns an address segment with 5 address lines' do
      expect(alma_address.to_h['line1']).to eq 'street'
      expect(alma_address.to_h['line2']).to eq 'apartment'
      expect(alma_address.to_h['line3']).to eq 'suite'
      expect(alma_address.to_h['line4']).to eq 'room'
      expect(alma_address.to_h['line5']).to eq 'bed'
      expect(alma_address.to_h['line6']).to be_nil
      expect(alma_address.to_h['city']).to eq 'Schoenhut'
      expect(alma_address.to_h['state_province']).to eq 'PA'
      expect(alma_address.to_h['country']['value']).to eq 'USA'
      expect(alma_address.to_h['start_date']).to eq '2026-11-01Z'
      expect(alma_address.to_h['address_type'].first['value']).to eq 'work'
      expect(alma_address.to_h['address_type'].size).to eq 1
      expect(alma_address.to_h['preferred']).to be true
      expect(alma_address.to_h['segment_type']).to eq 'Internal'
    end
  end

  context 'non-preferred home address with 2 address lines' do
    let(:lines) { %w[street apartment] }
    let(:postcode_city_state_country) { { postcode: '90211', city: 'Bertrem', state: 'VT', country: 'USA' } }
    let(:start_date) { '2026-11-01Z' }
    let(:address_type) { 'home' }
    let(:preferred) { false }
    it 'returns an address segment with 2 address lines' do
      expect(alma_address.to_h['line1']).to eq 'street'
      expect(alma_address.to_h['line2']).to eq 'apartment'
      expect(alma_address.to_h['line3']).to be_nil
      expect(alma_address.to_h['line4']).to be_nil
      expect(alma_address.to_h['line5']).to be_nil
      expect(alma_address.to_h['address_type'].first['value']).to eq 'home'
      expect(alma_address.to_h['preferred']).to be false
    end
  end
end
# rubocop:enable Metrics/BlockLength
