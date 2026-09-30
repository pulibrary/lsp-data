# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::OitPeople do
  subject(:oit_people) do
    described_class.new(token: 'token', base_url: 'https://api.edu')
  end
  context 'Status other than 200 returned from API call' do
    it 'returns nil for people' do
      stub_oit_response(fixture: 'oit_report_202_status.json', status: 202)
      report = oit_people.report
      expect(report[:status]).to eq 202
      expect(report[:people]).to be_nil
    end
  end

  context 'No parameters are provided for report' do
    it 'returns eligible and ineligible users' do
      stub_oit_response(fixture: 'oit_report_no_params.json')
      report = oit_people.report
      expect(report[:status]).to eq 200
      expect(report[:people].size).to eq 2
      expect(report[:people].first['EMPLID']).to eq '123456789'
      expect(report[:people].first['ELIGIBLE_INELIGIBLE']).to eq described_class::INELIGIBLE
      expect(report[:people][1]['EMPLID']).to eq '123456780'
      expect(report[:people][1]['ELIGIBLE_INELIGIBLE']).to eq described_class::ELIGIBLE
    end
  end

  context 'Eligible flag is provided' do
    it 'returns eligible users only' do
      stub_oit_response(fixture: 'oit_report_eligible_flag.json', path: '/E')
      report = oit_people.report(eligible_flag: described_class::ELIGIBLE)
      expect(report[:status]).to eq 200
      expect(report[:people].size).to eq 2
      expect(report[:people].first['ELIGIBLE_INELIGIBLE']).to eq described_class::ELIGIBLE
      expect(report[:people][1]['ELIGIBLE_INELIGIBLE']).to eq described_class::ELIGIBLE
    end
  end

  context 'Dates are provided' do
    it 'returns eligible and ineligible users with update times in the date range' do
      stub_oit_response(fixture: 'oit_report_dates.json', path: '/2026-09-01/2026-09-02')
      report = oit_people.report(dates: { begin_date: '2026-09-01', end_date: '2026-09-02' })
      expect(report[:people].size).to eq 2
      expect(report[:people].first['ELIGIBLE_INELIGIBLE']).to eq described_class::INELIGIBLE
      expect(report[:people].first['INSERT_UPDATE_DATETIME']).to eq '2026-09-01T14:30:47.000-05:00'
      expect(report[:people][1]['ELIGIBLE_INELIGIBLE']).to eq described_class::ELIGIBLE
      expect(report[:people][1]['INSERT_UPDATE_DATETIME']).to eq '2026-09-01T14:32:47.000-05:00'
    end
  end

  context 'Dates and eligible flag are provided' do
    it 'returns eligible user with update time in the date range' do
      stub_oit_response(fixture: 'oit_report_dates_eligible_flag.json', path: '/E/2026-09-01/2026-09-02')
      report = oit_people.report(dates: { begin_date: '2026-09-01', end_date: '2026-09-02' }, eligible_flag: described_class::ELIGIBLE)
      expect(report[:people].size).to eq 1
      expect(report[:people].first['ELIGIBLE_INELIGIBLE']).to eq described_class::ELIGIBLE
      expect(report[:people].first['INSERT_UPDATE_DATETIME']).to eq '2026-09-01T14:32:47.000-05:00'
    end
  end
end
