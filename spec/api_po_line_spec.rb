# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
RSpec.describe LspData::ApiPoLine do
  subject(:po_line) do
    described_class.new(po_line_json: stub_json_fixture(fixture: fixture))
  end
  context 'PO Line retrieved via API' do
    let(:fixture) { 'po_line.json' }
    it 'returns the po-line number' do
      expect(po_line.number).to eq 'POL-1'
    end
  end
end
