# frozen_string_literal: true

# Methods to retrieve bibliographic information from a MARC record
module LspData
  def auth_subfields_to_skip(field_tag)
    case field_tag
    when '100', '110'
      %w[0 1 6 e]
    else
      %w[0 1 6 j]
    end
  end

  def author(record)
    auth_fields = record.fields(%w[100 110 111])
    return if auth_fields.empty?

    auth_field = auth_fields.first
    auth_tag = auth_field.tag
    subf_to_skip = auth_subfields_to_skip(auth_tag)
    targets = auth_field.subfields.reject do |subfield|
      subf_to_skip.include?(subfield.code)
    end
    author = targets.map(&:value).join(' ')
    scrub_string(author)
  end

  def title_string(f245)
    return f245['a'] if f245['a']

    targets = f245.subfields.reject { |subfield| subfield.code == '6' }
    c_index = targets.index { |subfield| subfield.code == 'c' }
    c_index ||= -1
    subf_values = targets[0..c_index].map(&:value)
    subf_values.join(' ')
  end

  def title(record)
    f245 = record['245']
    return unless f245

    scrub_string(title_string(f245))
  end

  def description(record)
    f300 = record['300']
    return unless f300

    text = f300.subfields.map(&:value).join(' ')
    scrub_string(text)
  end

  def publisher(record)
    f260 = record['260']
    return publisher_info(f260) if f260

    f264 = record.fields('264')
    unless f264.empty?
      target_field = select_f264(f264)
      return publisher_info(target_field)
    end
    { pub_place: nil, pub_name: nil, pub_date: nil }
  end

  def publisher_info(field)
    pub_place = scrub_string(field['a'])
    pub_name = scrub_string(field['b'])
    pub_date = scrub_string(field['c'])
    { pub_place: pub_place, pub_name: pub_name, pub_date: pub_date }
  end

  def select_f264(f264)
    f264.min_by(&:indicator2)
  end

  def scrub_string(string)
    new_string = string.to_s.dup
    new_string.strip!
    new_string[-1] = '' if new_string[-1] =~ %r{[.,:/=]}
    new_string.strip!
    new_string.gsub(/(\s){2, }/, '\1')
  end
end
