# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ZhonghuaRecord do
  subject(:zhonghua_record) do
    described_class.new(rows: rows, conn: conn)
  end

  let(:conn) do
    Z3950Connection.new(host: OCLC_Z3950_ENDPOINT,
                        database_name: OCLC_Z3950_DATABASE_NAME,
                        credentials: { user: OCLC_Z3950_USER, password: OCLC_Z3950_PASSWORD })
  end

  context 'single row where ISBN is found in WorldCat, but URLs are not' do
    let(:rows) do
      [
        {
          'URL' => 'https://jingdian.ancientbooks.cn/6/book/4855843',
          '唯一标识符' => 'ZHB011009379',
          '标准编号' => 'ISBN 978-7-101-14689-9',
          '题名' => 'CHINESE_TITLE',
          '其他题名信息' => 'CHINESE_SERIES'
        }
      ]
    end

    it 'returns a record containing the ISBN, other fields transformed according to row data' do
      expect(zhonghua_record.rec['001']).to eq nil
      isbn020 = zhonghua_record.rec.fields('020').map(&:to_s).join('|')
      expect(isbn020).to include rows[0]['标准编号'].gsub(/[^0-9Xx]/, '')
      expect(zhonghua_record.rec['245'].value).to eq rows[0]['题名']
      removed880s = zhonghua_record.rec.fields('880').find { |field| %w[245 490 505 830].include?(field['6'][0..2]) }
      expect(removed880s).to eq nil
      expect(zhonghua_record.rec['490'].value).to eq rows[0]['其他题名信息']
      expect(zhonghua_record.rec['830'].value).to eq rows[0]['其他题名信息']
      expect(zhonghua_record.rec['956'].value).to eq rows[0]['URL']
    end
  end
end
