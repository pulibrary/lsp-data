# frozen_string_literal: true

# Methods to retrieve call number information from a MARC record
module LspData
  ### If specified as an LC call number, break it up into parts;
  ###   if not, return first subfield as full class and item subfield as Cutter
  def call_num_from_bib_field(record:, field_tag:, assume_lc: true)
    call_nums = []
    record.fields(field_tag).select { |f| f['a'] }.each do |field|
      primary_subfield = field.subfields.find { |s| s.code == 'a' }
      item_subfields = field.subfields.select { |s| s.code == 'b' }
      call_nums << LspData::ParsedCallNumber.new(primary_subfield: primary_subfield,
                                                 item_subfields: item_subfields,
                                                 assume_lc: assume_lc)
    end
    call_nums
  end

  def holding_fields_for_call_nums(field_array, inst_suffix, lc_only)
    standard_fields = field_array.select do |field|
      field['8'] =~ /22[0-9]+#{inst_suffix}$/ && field['h']
    end
    if lc_only
      standard_fields.select { |field| field.indicator1 == '0' }
    else
      standard_fields
    end
  end

  ### Call numbers are grouped by holding ID
  def call_num_from_alma_holding_field(record:, field_tag:, inst_suffix:, lc_only: true)
    hash = {}
    holding_fields_for_call_nums(record.fields(field_tag), inst_suffix, lc_only).each do |field|
      holding_id = field['8']
      call_num = LspData::ParsedCallNumber.new(primary_subfield: field.subfields.find { |s| s.code == 'h' },
                                               item_subfields: field.subfields.select { |s| s.code == 'i' },
                                               assume_lc: field.indicator1 == '0')
      hash[holding_id] ||= []
      hash[holding_id] << call_num
    end
    hash
  end

  def all_call_nums_from_merged_bib(record:, inst_suffix:, lc_only: true, holding_field_tag: '852')
    f050 = call_num_from_bib_field(record: record, field_tag: '050')
    f090 = call_num_from_bib_field(record: record, field_tag: '090')
    holdings = call_num_from_alma_holding_field(record: record,
                                                field_tag: holding_field_tag,
                                                inst_suffix: inst_suffix,
                                                lc_only: lc_only)
    { f050: f050, f090: f090, holdings: holdings }
  end
end
