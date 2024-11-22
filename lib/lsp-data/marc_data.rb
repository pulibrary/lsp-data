# frozen_string_literal: true

module LspData
  ### If specified as an LC call number, break it up into parts;
  ###   if not, return first subfield as full class and item subfield as Cutter
  def parse_call_number(primary_subfield:, item_subfields:, assume_lc: true)
    cutters = item_subfields.map(&:value)
    full_call_num = "#{primary_subfield.value} #{cutters.join(' ')}".strip
    is_lc = false
    if assume_lc
      main_lc_class = nil
      sub_lc_class = nil
      if primary_subfield.value[0] =~ /[A-Z]/
        is_lc = true
        main_lc_class = primary_subfield.value[0]
        sub_lc_class = primary_subfield.value.gsub(/^([A-Z]+)[^A-Z].*$/, '\1')
      end
      { is_lc: is_lc,
        main_lc_class: main_lc_class,
        sub_lc_class: sub_lc_class,
        classification: primary_subfield.value,
        full_call_num: full_call_num,
        cutters: cutters }
    else
      { is_lc: is_lc,
        main_lc_class: nil,
        sub_lc_class: nil,
        classification: primary_subfield.value,
        full_call_num: full_call_num,
        cutters: cutters }
    end
  end

  def call_num_from_bib_field(record:, field_tag:)
    return [] unless record[field_tag]

    call_nums = []
    record.fields(field_tag).each do |field|
      call_num = field.subfields.select do |subfield|
        %w[a b].include?(subfield.code)
      end.map(&:value).join(' ')
      call_num.strip!
      call_nums << call_num
    end
    call_nums
  end

  ### Call numbers are grouped by holding ID
  def call_num_from_alma_holding_field(record:, field_tag:, inst_suffix:, lc_only: true)
    return { } unless record[field_tag]

    hash = {}
    record.fields(field_tag).select do |field|
      field['8'] =~ /22[0-9]+#{inst_suffix}$/
    end.each do |field|
      next if lc_only && field.indicator1 != '0'

      holding_id = field['8']
      call_num = field.subfields.select do |subfield|
        %w[h i].include?(subfield.code)
      end.map(&:value).join(' ')
      call_num.strip!
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
