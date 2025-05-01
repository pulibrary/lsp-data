# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::OitPersonToAlma do
  subject(:person) do
    described_class.new(person: person, xml: xml)
  end

  context 'Person is an active graduate student' do
    let(:oit_fixture) { 'oit_person_grad.json' }
    let(:alma_fixture) { 'alma_person_grad.xml' }
    let(:person) { stub_json_fixture(fixture: oit_fixture) }
    let(:alma_xml) { stub_xml_fixture(fixture: alma_fixture) }
    it 'transforms the person into an Alma person' do
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.users do
          OitPersonToAlma.new(person: person, xml: xml).convert
        end
      end
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end

  context 'Person is a retired faculty member' do
    let(:oit_fixture) { 'oit_person_retiree.json' }
    let(:alma_fixture) { 'alma_person_retiree.xml' }
    let(:person) { stub_json_fixture(fixture: oit_fixture) }
    let(:alma_xml) { stub_xml_fixture(fixture: alma_fixture) }
    it 'transforms the person into an inactive Alma person' do
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.users do
          OitPersonToAlma.new(person: person, xml: xml).convert
        end
      end
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end

  context 'Person is an inactive undergraduate student' do
    let(:oit_fixture) { 'oit_person_ugrd_ineligible.json' }
    let(:alma_fixture) { 'alma_person_ugrd_ineligible.xml' }
    let(:person) { stub_json_fixture(fixture: oit_fixture) }
    let(:alma_xml) { stub_xml_fixture(fixture: alma_fixture) }
    it 'transforms the person into an inactive Alma person' do
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.users do
          OitPersonToAlma.new(person: person, xml: xml).convert
        end
      end
      expect(builder.to_xml).to eq alma_xml.to_xml
    end
  end
end
