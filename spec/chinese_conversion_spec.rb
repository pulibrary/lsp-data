# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::ChineseConversion do
  subject(:chinese_conv) do
    described_class.new(chi_simp_title)
  end

  let(:chi_simp_title) { '中华人民共和国~㛟𠰷' }

  context 'Chinese title with some Simplified characters and characters that are the same in both systems' do
    it 'returns Simplified characters converted to Traditional, with all other characters unchanged' do
      expect(chinese_conv.converted).to eq '中華人民共和國~𡞵嚧'
    end
  end
end
