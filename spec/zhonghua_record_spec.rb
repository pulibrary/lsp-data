# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ZhonghuaRecord do
  subject(:zhonghua_record) do
    described_class.new(title_info: { main_title: main_title, series_title: series_title,
                                      components: components, isbn: isbn }, conn: conn)
  end

  let(:conn) do
    Z3950Connection.new(host: OCLC_Z3950_ENDPOINT, database_name: OCLC_Z3950_DATABASE_NAME,
                        credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end

  context 'no WorldCat record is found' do
    let('main_title') { 'no title' }
    let('series_title') { 'series' }
    let('components') do
      [{
        url: 'thisisnotaurl',
        alternate_url: nil
      }]
    end
    let('isbn') { nil }

    it 'returns nil' do
      expect(zhonghua_record.original_record).to be_nil
      expect(zhonghua_record.transformed_record).to be_nil
    end
  end

  context 'single row where ISBN is found in WorldCat, but URLs are not' do
    let('main_title') { '龍文鞭影' }
    let('series_title') { 'CHINESE_SERIES' }
    let('components') do
      [{
        url: 'jingdian.ancientbooks.cn/6/book/4855843',
        alternate_url: 'ZHB011009379'
      }]
    end
    let('isbn') { '9787101146899' }

    it 'returns a record containing the ISBN, other fields transformed according to row data' do
      new_record = zhonghua_record.transformed_record
      expect(new_record['001']).to be nil
      expect(new_record.fields('020').map(&:value)).to include isbn
      expect(new_record['245'].value).to eq main_title
      expect(new_record.fields('880').map { |f| f['6'].to_s[0..2] }).not_to include(%w[245 490 505 830])
      expect(new_record['490'].value).to eq series_title
      expect(new_record['505']).to be nil
      expect(new_record['830'].value).to eq series_title
      expect(new_record['856']).to be nil
      expect(new_record['956'].value).to eq "https://#{components[0][:url]}"
    end
  end

  context 'multiple rows, ISBN found' do
    let('main_title') { '春秋長曆二種' }
    let('series_title') { nil }
    let('components') do
      [
        {
          title: '毛詩序説',
          url: 'jingdian.ancientbooks.cn/6/book/4147592',
          alternate_url: 'ZHB011005659'
        },
        {
          title: '春秋長曆',
          url: 'jingdian.ancientbooks.cn/6/book/4147854',
          alternate_url: 'ZHB011005654'
        }
      ]
    end
    let('isbn') { '9787101151954' }

    it 'returns a record containing the ISBN and all component URLs/titles' do
      new_record = zhonghua_record.transformed_record
      expect(new_record['001']).to be nil
      expect(new_record.fields('020').map(&:value)).to include(a_string_matching(isbn))
      expect(new_record['245'].value).to eq main_title
      expect(new_record.fields('880').map { |f| f['6'].to_s[0..2] }).not_to include(%w[245 490 505 830])
      expect(new_record['490']).to be nil
      expect(new_record.fields('505').first.subfields.map(&:value)).to match_array(components.map { |c| c[:title] })
      expect(new_record['830']).to be nil
      expect(new_record['856']).to be nil
      expect(new_record.fields('956').map { |f| f['3'].to_s }).to match_array(components.map { |c| c[:title] })
      expect(new_record.fields('956').map { |f| f['u'].to_s }).to match_array(components.map { |c|
        "https://#{c[:url]}"
      })
    end
  end

  context 'long TOC spread over multiple 505s' do
    let('main_title') { '春秋長曆二種' }
    let('series_title') { nil }
    let('volCount') { 1000 }
    let('components') do
      Array.new(volCount) do |i|
        {
          title: "第#{i + 1}卷",
          url: "jingdian.ancientbooks.cn/6/book/1234#{i + 1}",
          alternate_url: "ZHB01234#{i + 1}"
        }
      end
    end
    let('isbn') { '9787101151954' }

    it 'returns a record containing multple 505s' do
      new_record = zhonghua_record.transformed_record
      expect(new_record['001']).to be nil
      expect(new_record['245'].value).to eq main_title
      expect(new_record.fields('505').length).to be > 1
      expect(new_record.fields('505').map(&:subfields).flatten.length).to eq volCount
      expect(new_record.fields('505').filter { |f| f.to_s.bytesize > 5000 }.count).to eq 0
    end
  end
end
