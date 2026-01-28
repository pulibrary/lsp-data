# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::FiggyDigitalObject do # rubocop:disable Metrics/BlockLength
  subject(:figgy_object) do
    described_class.new(manifest_info: stub_json_fixture(fixture: fixture), mms_id: mms_id)
  end
  let(:mms_id) { '99129146648906421' }

  context 'private visibility item' do
    let(:fixture) { 'private_figgy_report.json' }

    it 'has IIIF manifest URL, manifest identifier, MMS ID, visibility, label, and ARK' do
      expect(figgy_object.mms_id).to eq mms_id
      expect(figgy_object.visibility).to eq 'private'
      expect(figgy_object.manifest_url).to eq 'https://figgy.princeton.edu/concern/scanned_resources/123/manifest'
      expect(figgy_object.manifest_identifier).to eq '123'
      expect(figgy_object.ark).to eq 'http://arks.princeton.edu/ark:/88435/ab01cd39z'
      expect(figgy_object.label).to eq 'Label'
    end
  end

  context 'private visibility item with nil label' do
    let(:fixture) { 'private_figgy_report_nil_label.json' }

    it 'has empty label' do
      expect(figgy_object.manifest_identifier).to eq '123'
      expect(figgy_object.label).to eq ''
    end
  end

  context 'open visibility item with language tag for label' do
    let(:fixture) { 'open_figgy_report.json' }

    it 'has all manifest metadata' do
      expect(figgy_object.mms_id).to eq mms_id
      expect(figgy_object.visibility).to eq 'open'
      expect(figgy_object.manifest_url).to eq 'https://figgy.princeton.edu/concern/scanned_resources/123/manifest'
      expect(figgy_object.manifest_identifier).to eq '123'
      expect(figgy_object.ark).to eq 'http://arks.princeton.edu/ark:/88435/ab01cd39z'
      expect(figgy_object.label).to eq 'Label'
    end
  end
end
