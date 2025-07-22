# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::Z3950Connection do
  subject(:connection) do
    described_class.new(host: host, port: port, database_name: database_name, element_set_name: element_set_name)
  end

  context 'valid connection parameters' do
    let(:host) { 'lx2.loc.gov' }
    let(:port) { 210 }
    let(:database_name) { 'LCDB' }
    let(:element_set_name) { 'F' }

    it 'returns a ZOOM::Connection class' do
      expect(connection.connection.class).to eq ZOOM::Connection
    end
  end
end
