# frozen_string_literal: true

module LspData
  ### This class parses a call number; if it is assumed to be an LC call number,
  ###   it splits the call number into its parts
  class ParsedCallNumber
    attr_reader :primary_subfield, :item_subfields, :assume_lc

    def initialize(primary_subfield:, item_subfields:, assume_lc:)
      @primary_subfield = primary_subfield
      @item_subfields = item_subfields
      @assume_lc = assume_lc
    end

    def lc?
      if assume_lc
        primary_subfield.value[0] =~ /[A-Z]/ ? true : false
      else
        false
      end
    end

    def primary_lc_class
      primary_subfield.value[0] if lc?
    end

    def sub_lc_class
      primary_subfield.value.gsub(/^([A-Z]+)[^A-Z].*$/, '\1') if lc?
    end

    def classification
      primary_subfield.value.strip
    end

    def cutters
      item_subfields.map(&:value)
    end

    def full_call_num
      "#{primary_subfield.value} #{cutters.join(' ')}".strip
    end
  end
end
