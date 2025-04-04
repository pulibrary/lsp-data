# frozen_string_literal: true

require_relative './../lib/lsp-data'
require 'spec_helper'
require 'byebug'

RSpec.describe LspData::GoogleExport do
  subject(:export) do
    described_class.new(input_file: input_file,
                        output_dir: output_dir,
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
  context 'File of records has one eligible record and one ineligible record' do
    let(:fixture) { 'google_2_records_one_eligible.marcxml' }
    let(:input_file) { ("#{FIXTURE_DIR}/#{fixture}") }
    let(:output_dir) { FIXTURE_DIR }

    it 'generates a file with the eligible record' do
      response = export
      reader = MARC::XMLReader.new("#{output_dir}/filtered_#{fixture}")
      filtered_records = []
      reader.each { |record| filtered_records << record }
      expect(filtered_records.size).to eq 1
      expect(filtered_records.first['001'].value).to eq '99106421'
      File.unlink("#{output_dir}/filtered_#{fixture}")
    end
  end
end
