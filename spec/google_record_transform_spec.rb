# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
require 'byebug'

RSpec.describe LspData::GoogleRecordTransform do
  subject(:transformed) do
    described_class.new(original_record: record,
                        exclude_libraries: exclude_libraries,
                        exclude_locations: exclude_locations)
  end

  let(:exclude_locations) do
    %w[
        recap$pe
        firestone$docsm
        firestone$flm
        firestone$flmm
        firestone$flmp
        firestone$gestf
        eastasian$hygf
        firestone$flmb
        lewis$mic
        eastasian$ql
        firestone$pf
        stokes$mic
        mudd$mic
        marquand$mic
        engineer$mic
      ]
  end

  let(:exclude_libraries) { %w[online obsolete resshare techserv RES_SHARE] }
  context 'Record has no eligible items' do
    let(:fixture) { 'google_no_eligible_item.marcxml' }
    let(:record) { stub_bib_record(fixture) }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Record has eligible items but is suppressed' do
    let(:fixture) { 'google_eligible_item_suppressed.marcxml' }
    let(:record) { stub_bib_record(fixture) }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Record has eligible items but is not textual material' do
    let(:fixture) { 'google_eligible_item_wrong_format.marcxml' }
    let(:record) { stub_bib_record(fixture) }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Record has some eligible items' do
    let(:fixture) { 'google_eligible_item.marcxml' }
    let(:record) { stub_bib_record(fixture) }

    it 'returns changed record with one 955 record per eligible item and no other 9xx' do
      new_record = transformed.changed_record
      f9xx_tags = new_record.fields('900'..'999').map(&:tag).uniq
      expect(f9xx_tags).to eq %w[955]
      expect(new_record.fields('955').size).to eq 1
      expect(new_record['955']['b']).to eq 'bc1'
    end
  end
end
