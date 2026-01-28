# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'byebug'
require 'spec_helper'

RSpec.describe LspData::AlmaDigitalObject do # rubocop:disable Metrics/BlockLength
  subject(:alma_object) do
    described_class.new(mms_id: mms_id, figgy_object: figgy_object)
  end
  let(:mms_id) { '99129146648906421' }
  let(:figgy_object) do
    FiggyDigitalObject.new(manifest_info: stub_json_fixture(fixture: fixture),
                           mms_id: mms_id)
  end

  context 'private visibility Figgy object' do
    let(:fixture) { 'private_figgy_report.json' }
    let(:manifest_url) { 'https://figgy.princeton.edu/concern/scanned_resources/123/manifest' }
    it 'has all required elements' do
      expect(alma_object.mms_id).to eq mms_id
      expect(alma_object.repository_code).to eq 'figgy-private'
      expect(alma_object.marc_record['999']['a']).to eq '123'
      expect(alma_object.marc_record['999']['b']).to eq 'Label'
      expect(alma_object.marc_record['999']['c']).to eq 'ab01cd39z'
      expect(alma_object.marc_record['999']['d']).to eq manifest_url
    end
  end

  context 'open visibility Figgy object' do
    let(:fixture) { 'open_figgy_report.json' }
    let(:manifest_url) { 'https://figgy.princeton.edu/concern/scanned_resources/123/manifest' }
    let(:xml_fixture) { stub_xml_fixture(fixture: 'alma_digital_record.xml') }
    it 'has all required elements' do
      expect(alma_object.repository_code).to eq 'figgy-open'
      expect(alma_object.marc_record['999']['a']).to eq '123'
      expect(alma_object.marc_record['999']['b']).to eq 'Label'
      expect(alma_object.marc_record['999']['d']).to eq manifest_url
      expect(alma_object.record).to eq xml_fixture.to_xml.gsub("<?xml version=\"1.0\"?>\n", '')
    end
  end
end
