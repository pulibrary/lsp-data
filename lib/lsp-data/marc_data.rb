# frozen_string_literal: true

module LspData
  def call_num_from_bib_field(record:, field_tag:)
    return nil unless record[field_tag]

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
end
