# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::Z3950Connection do
  subject(:connection) do
    described_class.new(host: host, port: port, database_name: database_name, element_set_name: element_set_name)
  end

  let(:host) { 'lx2.loc.gov' }
  let(:port) { 210 }
  let(:database_name) { 'LCDB' }
  let(:element_set_name) { 'F' }

  context 'valid connection parameters' do
    it 'returns a ZOOM::Connection class' do
      expect(connection.connection.class).to eq ZOOM::Connection
    end
  end

  context 'ISBN provided that exists in database for a search' do
    let(:index) { 7 }
    let(:identifier) { '9781984899422' }

    it 'returns a valid record' do
      record = connection.search_by_id(index: index, identifier: identifier).first
      f020 = record.fields('020').map { |field| field['a'] }
      expect(record.class).to eq MARC::Record
      expect(f020).to include identifier
    end
  end
end
