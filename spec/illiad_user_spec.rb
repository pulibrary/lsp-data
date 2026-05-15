# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ILLiadUser do
  subject(:illiad_user) do
    described_class.new(transaction_info: transaction_info)
  end

  context 'standard user' do
    let(:transaction_info) do
      {
        'UserName' => 'ab1234',
        'LastName' => 'User',
        'FirstName' => 'Test',
        'SSN' => '22101123456789',
        'Status' => 'U - Undergraduate',
        'Department' => 'Research Computing',
        'NVTGC' => 'ILL',
        'LastChangedDate' => Time.new(2025, 3, 1, 2, 11, 1, '-05:00'),
        'Site' => 'Firestone',
        'ExpirationDate' => Time.new(2028, 3, 1, 2, 11, 1, '-05:00'),
        'Number' => '123456789'
      }
    end
    it 'returns an object with all elements' do
      expect(illiad_user.username).to eq 'ab1234'
      expect(illiad_user.last_name).to eq 'User'
      expect(illiad_user.first_name).to eq 'Test'
      expect(illiad_user.patron_barcode).to eq '22101123456789'
      expect(illiad_user.status).to eq 'U - Undergraduate'
      expect(illiad_user.department).to eq 'Research Computing'
      expect(illiad_user.nvtgc).to eq 'ILL'
      expect(illiad_user.modification_date).to eq Time.new(2025, 3, 1, 2, 11, 1, '-05:00')
      expect(illiad_user.site).to eq 'Firestone'
      expect(illiad_user.expiration_date).to eq Time.new(2028, 3, 1, 2, 11, 1, '-05:00')
      expect(illiad_user.primary_id).to eq '123456789'
    end
  end
end
