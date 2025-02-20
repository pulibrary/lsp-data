# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'


### Given an OCLC number, a token, and a connection, return a status code and
###   JSON body
RSpec.describe LspData::OCLCUnset do
  subject(:unset) do
    described_class.new(oclc_num: oclc_num, token: token, conn: conn)
  end

  context 'Holding is not yet unset' do
    let(:url) { 'https://metadata.api.oclc.org/worldcat' }
    let(:conn) { api_conn(url) }
    let(:oclc_num) { '1' }
    let(:token) { 'abc' }

    it 'returns message that the holding was unset' do
      stub_unsend(fixture: 'oclc_unsend_success.json',
                  url: url,
                  oclc_num: oclc_num,
                  token: token,
                  desired_status: 200)
      expect(unset.status).to eq 200
      expect(unset.message['message']).to eq 'Unset Holdings Succeeded.'
    end
  end
  context 'Holding is already unset' do
    let(:url) { 'https://metadata.api.oclc.org/worldcat' }
    let(:conn) { api_conn(url) }
    let(:oclc_num) { '1' }
    let(:token) { 'abc' }

    it 'returns message that the holding was already unset' do
      stub_unsend(fixture: 'oclc_unsend_no_update.json',
                  url: url,
                  oclc_num: oclc_num,
                  token: token,
                  desired_status: 200)
      expect(unset.status).to eq 200
      expect(unset.message['message']).to eq 'WorldCat Holding already unset.'
    end
  end
end
