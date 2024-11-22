module LspData
  class ParsedCallNumber
    attr_reader :primary_subfield, :item_subfields, :assume_lc

    def initialize(primary_subfield:, item_subfields:, assume_lc:)
      @primary_subfield = primary_subfield
      @item_subfields = item_subfields
      @assume_lc = assume_lc
    end

    def primary_lc_class
      @primary_lc_class ||= begin
                              if assume_lc
                                primary_subfield.value[0] =~ /[A-Z]/ ? primary_subfield.value[0] : nil
                              else
                                nil
                              end
                            end
      @primary_lc_class
    end
  end
end
