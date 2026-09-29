# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe LspData::OitPersonToAlma do
  subject(:person) do
    described_class.new(person: person, xml: xml)
  end

  let(:person) { stub_json_fixture(fixture: oit_fixture) }
  let(:alma_xml) { stub_xml_fixture(fixture: alma_fixture) }
  let(:builder) do
    Nokogiri::XML::Builder.new do |xml|
      xml.users do
        OitPersonToAlma.new(person: person, xml: xml).alma_person
      end
    end
  end
  context 'Person is an active graduate student' do
    let(:oit_fixture) { 'oit_person_grad.json' }
    let(:alma_fixture) { 'alma_person_grad.xml' }
    it 'transforms the person into an Alma person' do
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end

  context 'Person is a retired faculty member' do
    let(:oit_fixture) { 'oit_person_retiree.json' }
    let(:alma_fixture) { 'alma_person_retiree.xml' }
    it 'transforms the person into an inactive Alma person' do
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end

  context 'Person is an inactive undergraduate student' do
    let(:oit_fixture) { 'oit_person_ugrd_ineligible.json' }
    let(:alma_fixture) { 'alma_person_ugrd_ineligible.xml' }
    it 'transforms the person into an inactive Alma person' do
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end

  context 'Person is a staff member associated with PPPL' do
    let(:oit_fixture) { 'oit_person_pppl.json' }
    let(:alma_fixture) { 'alma_person_pppl.xml' }
    it 'creates a user with multiple statistical categories' do
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end

  context 'Person has no statistical category' do
    let(:oit_fixture) { 'oit_person_no_category.json' }
    let(:alma_fixture) { 'alma_person_no_category.xml' }
    it 'creates a user with no statistical categories' do
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end
end
# rubocop:enable Metrics/BlockLength
