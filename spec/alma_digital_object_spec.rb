# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'byebug'
require 'spec_helper'

RSpec.describe LspData::AlmaDigitalObject do # rubocop:disable Metrics/BlockLength
  subject(:alma_object) do
    described_class.new(mms_id: mms_id, figgy_object: figgy_object)
  end
  let(:conn) { LspData.api_conn('https://figgy.princeton.edu/concern') }
  let(:mms_id) { '99129146648906421' }
  let(:figgy_object) do
    FiggyDigitalObject.new(manifest_info: stub_json_fixture(fixture: fixture),
                           mms_id: mms_id, conn: conn)
  end

  context 'private visibility Figgy object' do
    let(:fixture) { 'private_figgy_report.json' }
    let(:manifest_url) { 'https://figgy.princeton.edu/concern/scanned_resources/123/manifest' }
    it 'has all required elements' do
      nokogiri_record = Nokogiri::XML(alma_object.record)
      expect(alma_object.mms_id).to eq mms_id
      expect(alma_object.repository_code).to eq 'figgy-private'
      expect(alma_object.marc_record['999']['a']).to eq '123'
      expect(alma_object.marc_record['999']['b']).to be_nil
      expect(alma_object.marc_record['999']['c']).to be_nil
      expect(alma_object.marc_record['999']['d']).to eq manifest_url
    end
  end

  context 'open visibility Figgy object' do
    let(:fixture) { 'open_figgy_report.json' }
    let(:manifest_fixture) { 'figgy_manifest.json' }
    let(:url_unique_portion) { 'scanned_resources/123' }

    it 'has additional elements for an open manifest' do
      stub_get_manifest_response(manifest_unique_portion: url_unique_portion, fixture: manifest_fixture)
      expect(alma_object.repository_code).to eq 'figgy-open'
      expect(alma_object.marc_record['999']['b']).to eq 'Label'
      expect(alma_object.marc_record['999']['c']).to eq '1/123intermediate_file/square/225,/0/default.jpg'
    end
  end
end
