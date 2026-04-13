# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

### Client to imitate a TinyTds client
class FakeClient
  def initialize(credentials)
    error_string = "Unable to connect: TDS server is unavailable or does not exist (#{credentials[:host]})"
    return unless credentials[:host] != 'goodhost'

    raise TinyTds::Error, error_string
  end

  # rubocop:disable Metrics/MethodLength
  def execute(_query)
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
  # rubocop:enable Metrics/MethodLength
end
# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::ILLiad do
  let(:credentials) do
    { username: 'gooduser', password: 'goodpass', host: 'goodhost', database: 'gooddb' }
  end
  let(:client) { TinyTds::Client }
  subject(:illiad) do
    described_class.new(tds_client_class: FakeClient, credentials: credentials)
  end

  context 'valid ILLiad credentials' do
    it 'returns a TinyTds Client as a connection' do
      expect(illiad.conn.class).to eq FakeClient
    end
  end

  context 'invalid ILLiad credentials' do
    let(:credentials) do
      { username: 'gooduser', password: 'goodpass', host: 'badhost', database: 'gooddb' }
    end
    it 'raises an error' do
      expect { described_class.new(tds_client_class: FakeClient, credentials: credentials) }.to raise_error TinyTds::Error
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
      expect(illiad.all_borrowing.first.transaction_number).to eq(1)
    end
  end
end
# rubocop:enable Metrics/BlockLength
