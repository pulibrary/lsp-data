# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::AlmaEmail do
  subject(:alma_email) do
    described_class.new(email_address: email_address,
                        email_type: email_type,
                        preferred: preferred)
  end

  context 'preferred work email' do
    let(:email_address) { 'id@email.com' }
    let(:email_type) { 'work' }
    let(:preferred) { true }
    it 'returns a valid email segment' do
      expect(alma_email.to_h['email_address']).to eq 'id@email.com'
      expect(alma_email.to_h['preferred']).to be true
      expect(alma_email.to_h['email_type'].first['value']).to eq 'work'
      expect(alma_email.to_h['segment_type']).to eq 'Internal'
    end
  end

  context 'non-preferred personal email' do
    let(:email_address) { 'id2@email.com' }
    let(:email_type) { 'personal' }
    let(:preferred) { false }
    it 'returns a valid email segment' do
      expect(alma_email.to_h['email_address']).to eq 'id2@email.com'
      expect(alma_email.to_h['preferred']).to be false
      expect(alma_email.to_h['email_type'].first['value']).to eq 'personal'
      expect(alma_email.to_h['segment_type']).to eq 'Internal'
    end
  end
end
# rubocop:enable Metrics/BlockLength
