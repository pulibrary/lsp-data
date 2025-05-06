# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::OAuth do
  context 'Connection information is provided with no scope' do
    subject(:oauth) do
      described_class.new(client_id: client_id, client_secret: client_secret, url: url)
    end
    let(:url) { 'https://api.institution.com/token' }
    let(:client_id) { 'id' }
    let(:client_secret) { 'secret' }

    it 'returns authorization information' do
      stub_oauth(fixture: 'oclc_oauth_response.json', url: url)
      expect(oauth.response[:status]).to eq 200
      expect(oauth.response[:expiration].utc).to eq Time.utc(2025, 1, 6, 15, 28, 30)
      expect(oauth.response[:token]).to eq 'token'
    end
  end

  context 'Connection information is provided with a scope' do
    subject(:oauth) do
      described_class.new(client_id: client_id, client_secret: client_secret, url: url, scope: scope)
    end
    let(:url) { 'https://oauth.oclc.org/token' }
    let(:client_id) { 'id' }
    let(:client_secret) { 'secret' }
    let(:scope) { 'WorldCatMetadataAPI' }

    it 'returns authorization information' do
      stub_oauth(fixture: 'oclc_oauth_response.json', url: url, scope: scope)
      expect(oauth.response[:status]).to eq 200
      expect(oauth.response[:expiration].utc).to eq Time.utc(2025, 1, 6, 15, 28, 30)
      expect(oauth.response[:token]).to eq 'token'
    end
  end
end
