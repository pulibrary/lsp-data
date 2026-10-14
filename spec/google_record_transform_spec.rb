# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'
require 'byebug'

EXCLUDE_LOCATIONS = %w[
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
].freeze

EXCLUDE_LIBRARIES = %w[online obsolete resshare techserv RES_SHARE].freeze

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::GoogleRecordTransform do
  subject(:transformed) do
    described_class.new(original_record: stub_bib_record(fixture),
                        exclude_libraries: EXCLUDE_LIBRARIES,
                        exclude_locations: EXCLUDE_LOCATIONS)
  end

  context 'Record has no eligible items' do
    let(:fixture) { 'google_no_eligible_item.marcxml' }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Record has eligible items but is suppressed' do
    let(:fixture) { 'google_eligible_item_suppressed.marcxml' }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Notated music record has eligible items with no description and a holdings call number' do
    let(:fixture) { 'google_eligible_item_music.marcxml' }
    it 'returns changed record eligible item that has a call number and no description' do
      new_record = transformed.changed_record
      expect(new_record.fields('955').size).to eq 1
      expect(new_record['955']['a']).to eq '23106421'
      expect(new_record['955']['b']).to eq 'bc1'
      expect(new_record['955']['c']).to eq 'firestone$stacks'
      expect(new_record['955']['e']).to eq 'PG3492.58.U55 R93 2023'
      expect(new_record['955']['v']).to be_nil
    end
  end

  context 'Record has eligible item with a description and no holdings call number' do
    let(:fixture) { 'google_eligible_item_description_no_call_num.marcxml' }
    it 'returns changed record with eligible item that has no call number and a description' do
      new_record = transformed.changed_record
      expect(new_record.fields('955').size).to eq 1
      expect(new_record['955']['b']).to eq 'bc1'
      expect(new_record['955']['e']).to be_nil
      expect(new_record['955']['v']).to eq 'vol. 1'
    end
  end

  context 'Record has eligible items but is not textual material or notated music' do
    let(:fixture) { 'google_eligible_item_wrong_format.marcxml' }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Record has eligible items but is a host record' do
    let(:fixture) { 'google_eligible_item_host_record.marcxml' }
    it 'returns nil' do
      expect(transformed.changed_record).to be_nil
    end
  end

  context 'Record has some eligible items' do
    let(:fixture) { 'google_eligible_items.marcxml' }
    it 'returns changed record with one 955 record per eligible item and no other 9xx' do
      new_record = transformed.changed_record
      f9xx_tags = new_record.fields('900'..'999').map(&:tag).uniq
      barcodes = new_record.fields('955').map { |field| field['b'] }.sort
      expect(f9xx_tags).to eq %w[955]
      expect(new_record.fields('955').size).to eq 2
      expect(barcodes).to eq %w[bc1 bc2]
    end
  end
end
# rubocop:enable Metrics/BlockLength
