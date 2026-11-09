# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::AlmaPhone do
  subject(:alma_phone) do
    described_class.new(phone_number: phone_number,
                        phone_type: phone_type,
                        preferred: preferred)
  end

  context 'preferred office phone' do
    let(:phone_number) { '800-588-2300' }
    let(:phone_type) { 'office' }
    let(:preferred) { true }
    it 'returns a valid phone segment' do
      expect(alma_phone.to_h['phone_number']).to eq '800-588-2300'
      expect(alma_phone.to_h['preferred']).to be true
      expect(alma_phone.to_h['phone_type'].first['value']).to eq 'office'
      expect(alma_phone.to_h['segment_type']).to eq 'Internal'
    end
  end

  context 'non-preferred mobile phone' do
    let(:phone_number) { '800-123-4567' }
    let(:phone_type) { 'mobile' }
    let(:preferred) { false }
    it 'returns a valid phone segment' do
      expect(alma_phone.to_h['phone_number']).to eq '800-123-4567'
      expect(alma_phone.to_h['preferred']).to be false
      expect(alma_phone.to_h['phone_type'].first['value']).to eq 'mobile'
      expect(alma_phone.to_h['segment_type']).to eq 'Internal'
    end
  end
end
# rubocop:enable Metrics/BlockLength
