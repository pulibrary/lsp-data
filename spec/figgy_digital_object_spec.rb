# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::FiggyDigitalObject do # rubocop:disable Metrics/BlockLength
  subject(:figgy_object) do
    described_class.new(manifest_info: stub_json_fixture(fixture: fixture), mms_id: mms_id, conn: conn)
  end
  let(:conn) { LspData.api_conn('https://figgy.princeton.edu/concern/') }
  let(:mms_id) { '99129146648906421' }

  context 'private visibility item' do
    let(:fixture) { 'private_figgy_report.json' }

    it 'has IIIF manifest URL, manifest identifier, MMS ID, and visibility with no info from the manifest metadata' do
      expect(figgy_object.mms_id).to eq mms_id
      expect(figgy_object.visibility).to eq 'private'
      expect(figgy_object.manifest_url).to eq 'https://figgy.princeton.edu/concern/scanned_resources/123/manifest'
      expect(figgy_object.manifest_identifier).to eq '123'
      expect(figgy_object.manifest_metadata).to be nil
    end
  end

  context 'open visibility item' do
    let(:fixture) { 'open_figgy_report.json' }
    let(:manifest_fixture) { 'figgy_manifest.json' }
    let(:thumbnail_url) { 'https://iiif-cloud.princeton.edu/iiif/1/123intermediate_file/full/1000,/0/default.jpg' }
    let(:url_unique_portion) { 'scanned_resources/123' }
    let(:desired_manifest) do
      { ark: 'http://arks.princeton.edu/ark:/88435/ab01cd39z', label: 'Label',
        thumbnail: thumbnail_url, collections: ['Collection 1', 'Collection 2'] }
    end

    it 'has all manifest metadata' do
      stub_get_manifest_response(manifest_unique_portion: url_unique_portion, fixture: manifest_fixture)
      expect(figgy_object.visibility).to eq 'open'
      expect(figgy_object.manifest_metadata).to eq desired_manifest
    end
  end
end
