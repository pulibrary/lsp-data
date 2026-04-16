# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ILLiadBorrowing do
  subject(:illiad_borrowing) do
    described_class.new(transaction_info: transaction_info)
  end

  context 'transaction has ISBN in ISSN field' do
    let(:transaction_info) do
      {
        'TransactionNumber' => 1,
        'Username' => 'user',
        'CreationDate' => Time.new(2025, 3, 1, 2, 10, 1, '-05:00'),
        'TransactionStatus' => 'Request Finished',
        'TransactionDate' => Time.new(2025, 3, 1, 2, 11, 1, '-05:00'),
        'LendingLibrary' => 'PASG',
        'ISSN' => '9789004072725',
        'ESPNumber' => '1234',
        'ILLNumber' => 'NumberOne',
        'SystemID' => 'OCLC',
        'RequestType' => 'Loan',
        'ProcessType' => 'Borrowing'
      }
    end
    it 'returns an object with an ISBN and no ISSN' do
      expect(illiad_borrowing.username).to eq 'user'
      expect(illiad_borrowing.creation_date).to eq Time.new(2025, 3, 1, 2, 10, 1, '-05:00')
      expect(illiad_borrowing.transaction_status).to eq 'Request Finished'
      expect(illiad_borrowing.transaction_date).to eq Time.new(2025, 3, 1, 2, 11, 1, '-05:00')
      expect(illiad_borrowing.lending_library).to eq 'PASG'
      expect(illiad_borrowing.isbn).to eq '9789004072725'
      expect(illiad_borrowing.issn).to be_nil
      expect(illiad_borrowing.ill_number).to eq 'NumberOne'
      expect(illiad_borrowing.oclc_num).to eq '1234'
    end
  end
  context 'transaction has ISSN in ISSN field' do
    let(:transaction_info) do
      {
        'TransactionNumber' => 2,
        'Username' => 'user',
        'CreationDate' => Time.new(2025, 3, 1, 2, 10, 1, '-05:00'),
        'TransactionStatus' => 'Request Finished',
        'TransactionDate' => Time.new(2025, 3, 1, 2, 11, 1, '-05:00'),
        'LendingLibrary' => 'PASG',
        'ISSN' => '01934511',
        'ESPNumber' => '1234',
        'ILLNumber' => 'NumberOne',
        'SystemID' => 'Reshare:princeton',
        'RequestType' => 'Loan',
        'ProcessType' => 'Borrowing'
      }
    end
    it 'returns an object with an ISSN and no ISBN' do
      expect(illiad_borrowing.isbn).to be_nil
      expect(illiad_borrowing.issn).to eq '0193-4511'
      expect(illiad_borrowing.oclc_num).to eq '1234'
      expect(illiad_borrowing.creation_date).to eq Time.new(2025, 3, 1, 2, 10, 1, '-05:00')
    end
  end
  context 'SystemID is a system that does not use OCLC numbers' do
    let(:transaction_info) do
      {
        'TransactionNumber' => 3,
        'Username' => 'user',
        'CreationDate' => Time.new(2025, 3, 1, 2, 10, 1, '-05:00'),
        'TransactionStatus' => 'Request Finished',
        'TransactionDate' => Time.new(2025, 3, 1, 2, 11, 1, '-05:00'),
        'LendingLibrary' => 'PASG',
        'ISSN' => '01934511',
        'ESPNumber' => '1234',
        'ILLNumber' => 'NumberOne',
        'SystemID' => 'RLIN',
        'RequestType' => 'Loan',
        'ProcessType' => 'Borrowing'
      }
    end
    it 'returns an object with no OCLC number' do
      expect(illiad_borrowing.oclc_num).to be_nil
      expect(illiad_borrowing.transaction_number).to eq 3
    end
  end
end
