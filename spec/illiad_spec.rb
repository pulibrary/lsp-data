# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'
RSpec.describe LspData::ILLiad do
  subject(:illiad) do
    described_class.new
  end

  context 'valid ILLiad credentials' do
    it 'returns a TinyTds Client as a connection' do
      expect(illiad.conn.class).to eq TinyTds::Client
    end
  end

  context 'all borrowing requested' do
    let(:query) { illiad.send(:borrowing_query) }
    let(:response) do
      [
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
      ]
    end
    it 'returns ILLiadBorrowing objects' do
      stub_tinytds_call(query: query, response: response)
      expect(illiad.all_borrowing.first.transaction_number).to eq(1)
    end
  end
end
