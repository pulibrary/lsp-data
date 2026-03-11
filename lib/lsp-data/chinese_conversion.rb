# frozen_string_literal: true

### Codebase for parsing LSP data
module LspData
  ### Convert a Chinese text string from Simplified to Traditional characters
  class ChineseConversion
    attr_reader :original, :converted

    def initialize(original)
      @original = original
      @converted = to_trad
    end

    private

    def to_trad
      original.chars.map { |char| SIMP_TRAD_TABLE.key?(char) ? SIMP_TRAD_TABLE[char] : char }.join
    end
  end
end
