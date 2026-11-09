# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::AlmaUserStatistic do
  subject(:alma_user_statistic) do
    described_class.new(statistic_category)
  end

  context 'statistical category is provided' do
    let(:statistic_category) { 'PPPL' }
    it 'returns a valid statistic_category segment' do
      expect(alma_user_statistic.to_h['statistic_category']['value']).to eq 'PPPL'
      expect(alma_user_statistic.to_h['segment_type']).to eq 'Internal'
    end
  end
end
