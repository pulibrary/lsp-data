# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::AlmaDigitalObject do # rubocop:disable Metrics/BlockLength
  subject(:alma_object) do
    described_class.new(mms_id: mms_id, figgy_object: figgy_object)
  end
  let(:conn) { LspData.api_conn('https://figgy.princeton.edu/concern/scanned_resources') }
  let(:mms_id) { '99129146648906421' }

  context 'private visibility Figgy object' do
    let(:fixture) { 'private_figgy_report.json' }
    let(:figgy_object) do
      FiggyDigitalObject.new(manifest_info: stub_json_fixture(fixture: fixture),
                             mms_id: mms_id, conn: conn)
    end

    it 'has all required elements' do
      nokogiri_record = Nokogiri::XML(alma_object.record)
      expect(alma_object.mms_id).to eq mms_id
      expect(alma_object.repository_code).to eq 'figgy-private'
      expect(alma_object.iiif_manifest).to eq figgy_object.manifest_url
      expect(alma_object.primary_identifier).to eq figgy_object.manifest_identifier
      expect(nokogiri_record.at_xpath('record/header/identifier').text).to eq alma_object.primary_identifier
      expect(alma_object.marc_record['999']['a']).to eq alma_object.primary_identifier
      expect(alma_object.marc_record['999']['b']).to be_nil
      expect(alma_object.marc_record['999']['c']).to be_nil
      expect(alma_object.marc_record['999']['d']).to eq alma_object.iiif_manifest
    end
  end

  context 'open visibility Figgy object' do
    let(:fixture) { 'open_figgy_report.json' }
    let(:manifest_fixture) { 'figgy_manifest.json' }
    let(:figgy_object) do
      FiggyDigitalObject.new(manifest_info: stub_json_fixture(fixture: fixture),
                             mms_id: mms_id, conn: conn)
    end

    it 'has additional elements for an open manifest' do
      stub_get_manifest_response(manifest_identifer: figgy_object.manifest_identifier, fixture: manifest_fixture)
      expect(alma_object.repository_code).to eq 'figgy-open'
      expect(alma_object.primary_identifier).to eq 'ab01cd39z'
      expect(alma_object.marc_record['999']['b']).to eq figgy_object.manifest_metadata[:label]
      expect(alma_object.marc_record['999']['c']).to eq '1/file/default.jpg'
    end
  end
end
