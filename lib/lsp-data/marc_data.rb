# frozen_string_literal: true

module LspData
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

  def call_num_from_alma_holding_field(record:, field_tag:, inst_suffix:, lc_only: true)
    return [] unless record[field_tag]

    call_nums = []
    record.fields(field_tag).select do |field|
      field['8'] =~ /22[0-9]+#{inst_suffix}$/
    end.each do |field|
      next if lc_only && field.indicator1 != '0'

      call_num = field.subfields.select do |subfield|
        %w[h i].include?(subfield.code)
      end.map(&:value).join(' ')
      call_num.strip!
      call_nums << call_num
    end
    call_nums
  end
end
