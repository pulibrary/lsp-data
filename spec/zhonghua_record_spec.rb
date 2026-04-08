# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ZhonghuaRecord do
  subject(:zhonghua_record) do
    described_class.new(title_info: { main_title: main_title, series_title: series_title,
                                      url: url, alternate_url: alternate_url, isbn: isbn }, conn: conn)
  end

  let(:conn) do
    Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                        credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end

  context 'single row where ISBN is found in WorldCat, but URLs are not' do
    let('main_title') { '龍文鞭影' }
    let('series_title') { 'CHINESE_SERIES' }
    let('url') { 'jingdian.ancientbooks.cn/6/book/4855843' }
    let('alternate_url') { 'ZHB011009379' }
    let('isbn') { '9787101146899' }

    it 'returns a record containing the ISBN, other fields transformed according to row data' do
      new_record = zhonghua_record.transformed_record
      expect(new_record['001']).to eq nil
      expect(new_record.fields('020').map(&:value)).to include isbn
      expect(new_record['245'].value).to eq main_title
      expect(new_record.fields('880').map(&:field['6'][0..2]).not_to include(%w[245 490 505 830]))
      expect(new_record['490'].value).to eq series_title
      expect(new_record['830'].value).to eq series_title
      expect(new_record['956'].value).to eq "https://#{url}"
    end
  end
end
