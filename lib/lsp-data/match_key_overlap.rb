# frozen_string_literal: true

module LspData
  def strip_punctuation(string:, replace_char: ' ')
    new_string = string.dup
    new_string.gsub!(/%22/, replace_char)
    new_string.gsub!(/^\s*[aA]\s+/, '')
    new_string.gsub!(/^\s*[aA]n\s+/, '')
    new_string.gsub!(/^\s*[Tt]he\s+/, '')
    new_string.gsub!(/['{}]/, '')
    new_string.gsub!(/&/, 'and')
    new_string.gsub!(/[\u0020-\u0025\u0028-\u002f]/, replace_char)
    new_string.gsub!(/[\u003a-\u0040\u005b-\u0060]/, replace_char)
    new_string.gsub(/[\u007c\u007e\u00a9]/, replace_char)
  end

  def pad_with_underscores(string, string_length)
    new_string = string.dup.to_s # handle nil input
    new_string.gsub!(/\s+/, ' ')
    new_string.strip!
    new_string.gsub!(/\s/, '_')
    new_string[0, string_length].ljust(string_length, '_')
  end

  def trim_max_field_length(string)
    string[0..31_999]
  end

  def normalize_string(string)
    string.unicode_normalize(:nfd)
  end

  def normalize_string_and_remove_accents(string)
    string = normalize_string(string)
    string.gsub(/\p{InCombiningDiacriticalMarks}/, '')
  end

  def get_format_character(record)
    if record['245'] && record['245']['h'] =~ /electronic resource/ ||
       record.fields(%w[533 590]).any? { |f| f['a'] =~ /[Ee]lectronic reproduction/ } ||
       record.fields('300').any? { |f| f['a'] =~ /[Oo]nline resource/ } ||
       record.fields('007').any? { |f| f.value[0].downcase == 'c' } ||
       record.fields('337').any? { |f| f['a'] =~ /^c/ } ||
       (record['086'] && record['856'])
      'e'
    else
      'p'
    end
  end

  def process_title_field(title_field)
    title_key = ''.dup
    title_field.subfields.each do |subfield|
      next unless %w[a b p].include?(subfield.code)

      substring = subfield.value.dup
      substring = strip_punctuation(string: substring)
      substring = normalize_string_and_remove_accents(substring)
      substring.downcase!
      title_key << substring
    end
    title_key.strip!
    pad_with_underscores(title_key, 70)
  end

  def get_title_key_from880(record, field_num)
    f880 = record.fields('880').select { |f| f['6'] =~ /^245-#{field_num}/ }
    return nil if f880.empty?

    process_title_field(f880.first)
  end

  def get_title_key(record)
    field = record['245']
    return pad_with_underscores('', 70) if field.nil?

    title_key = nil
    subf6 = field['6'].dup
    if subf6
      field_num = subf6.gsub(/^880-(.*)$/, '\1')
      field_num.gsub!(/[^0-9].*$/, '')
      title_key = get_title_key_from880(record, field_num) unless field_num == ''
    end
    title_key = process_title_field(field) if title_key.nil?
    title_key
  end

  ### GoldRush uses the first 264 field to appear in the record, which could
  ###   end up using the copyright date or another type of date instead of
  ###   publication date
  def choose_26x_for_pub_date(record)
    f264 = record.fields('264').select { |f| f['c'] }
    pub_field = f264.select { |f| f.indicator2 == '1' }.first
    pub_field = f264.select { |f| f.indicator2 == '4' }.first if pub_field.nil?
    pub_field = f264.select { |f| f.indicator2 == '2' }.first if pub_field.nil?
    pub_field = f264.select { |f| f.indicator2 == '3' }.first if pub_field.nil?
    pub_field = f264.select { |f| f.indicator2 == '0' }.first if pub_field.nil?
    pub_field = record.fields('260').select { |f| f['c'] }.first if pub_field.nil?
    pub_field
  end

  def get_pub_date_from_pub_field(pub_field)
    return '0000' if pub_field.nil?

    subfc = pub_field['c'].dup
    pub_date = subfc.gsub(/^.*([0-9]{4})[^0-9]*$/, '\1')
    pub_date = '0000' if pub_date !~ /^[0-9]{4}$/
    pub_date
  end

  ### follows GoldRush documentation, but the logic is not clear why
  ###   Date2 is preferred over Date1; monographs only have a date in Date1
  def get_pub_date_key(record)
    pub_date = nil
    f008 = record['008']&.value
    if f008 && f008[6] == 'r'
      pub_date = f008[7..10]
    elsif f008
      pub_date = f008[11..14]
    end
    pub_date = nil if pub_date =~ /[^0-9]/
    if pub_date.nil?
      pub_field = choose_26x_for_pub_date(record)
      pub_date = get_pub_date_from_pub_field(pub_field)
    end
    pad_with_underscores(pub_date, 4)
  end

  def get_pagination_key(record)
    f300 = record.fields('300').select { |f| f['a'] }.first
    return pad_with_underscores('', 4) if f300.nil?

    subfa = f300['a'].dup
    subfa.gsub!(/^[^0-9]*([0-9]{4}).*$/, '\1')
    subfa = '' if subfa =~ /[^0-9]/
    pad_with_underscores(subfa, 4)
  end

  def edition_string_to_numbers(string)
    string.gsub!(/fir/, '1')
    string.gsub!(/sec/, '2')
    string.gsub!(/thi/, '3')
    string.gsub!(/fou/, '4')
    string.gsub!(/fiv/, '5')
    string.gsub!(/six/, '6')
    string.gsub!(/sev/, '7')
    string.gsub!(/eig/, '8')
    string.gsub!(/nin/, '9')
    string.gsub(/ten/, '10')
  end

  ### "For first edition monographs an integer of “1” is added to the matckey
  ###   even if the edition statement is blank or missing."
  def get_edition_key(record)
    f250 = record.fields('250').select { |f| f['a'] }.first
    return pad_with_underscores('1', 3) if f250.nil?

    subfa = f250['a'].dup
    subfa = normalize_string_and_remove_accents(subfa)
    subfa.downcase!
    subfa = edition_string_to_numbers(subfa)
    if subfa =~ /[0-9]/
      subfa.gsub!(/^[^0-9]*([0-9]+)[^0-9]*.*$/, '\1')
    else
      subfa.gsub!(/^[^a-z]*([a-z]+)[^0-9]*.*$/, '\1')
    end
    pad_with_underscores(subfa, 3)
  end

  def choose_26x_for_publisher(record)
    f264 = record.fields('264').select { |f| f['b'] }
    pub_field = f264.select { |f| f.indicator2 == '1' }.first
    pub_field = f264.select { |f| f.indicator2 == '4' }.first if pub_field.nil?
    pub_field = f264.select { |f| f.indicator2 == '2' }.first if pub_field.nil?
    pub_field = f264.select { |f| f.indicator2 == '3' }.first if pub_field.nil?
    pub_field = f264.select { |f| f.indicator2 == '0' }.first if pub_field.nil?
    pub_field = record.fields('260').select { |f| f['b'] }.first if pub_field.nil?
    pub_field
  end

  def get_publisher_from_pub_field(pub_field)
    return pad_with_underscores('', 5) if pub_field.nil?

    subfb = pub_field['b'].dup.to_s
    subfb = normalize_string_and_remove_accents(subfb)
    subfb = strip_punctuation(string: subfb)
    subfb.downcase!
    pad_with_underscores(subfb, 5)
  end

  ### GoldRush uses the first 264 found, which could be something other than
  ###   publication information
  def get_publisher_key(record)
    pub_field = choose_26x_for_publisher(record)
    get_publisher_from_pub_field(pub_field)
  end

  ### GoldRush documentation does not handle leaders with
  ###   invalid Unicode characters; encountered such errors when parsing ReCAP records
  def get_type_key(record)
    leader_val = record.leader.dup
    leader_val.force_encoding('utf-8')
    return pad_with_underscores('', 1) unless leader_val && leader_val.size > 9

    type_char = leader_val[6].dup
    type_char = normalize_string_and_remove_accents(type_char)
    pad_with_underscores(type_char, 1)
  end

  ### GoldRush does not remove accents
  def get_title_part_key(record)
    f245 = record.fields('245').select { |f| f['p'] }.first
    return pad_with_underscores('', 30) if f245.nil?

    title_part_key = ''.dup
    f245.subfields.each do |subfield|
      next unless subfield.code == 'p'

      part = subfield.value.dup
      part = normalize_string_and_remove_accents(part)
      part.strip!
      part = strip_punctuation(string: part)
      part.downcase!
      title_part_key << part[0..9]
    end
    pad_with_underscores(title_part_key, 30)
  end

  ### GoldRush does not remove accents
  def get_title_number_key(record)
    f245 = record.fields('245').select { |f| f['n'] }.first
    return pad_with_underscores('', 10) if f245.nil?

    subfn = f245['n'].dup.to_s
    subfn = normalize_string_and_remove_accents(subfn)
    subfn = strip_punctuation(string: subfn)
    subfn.downcase!
    pad_with_underscores(subfn, 10)
  end

  ### GoldRush includes the 130 field, even though that is not an author
  ### Goldrush documentation says the key is padded to 5 characters, but it
  ###   also says that it's padded to 20 characters
  def get_author_key(record)
    auth_fields = record.fields.select do |field|
      %w[100 110 111 113 130].include?(field.tag) &&
        field['a']
    end
    author_key = ''.dup
    auth_fields.each do |field|
      part = field['a'].dup
      part = normalize_string_and_remove_accents(part)
      part = strip_punctuation(string: part)
      part.downcase!
      author_key << part
    end
    pad_with_underscores(author_key, 20)
  end

  ### GoldRush does not remove diacritics
  def get_title_date_key(record)
    f245 = record.fields('245').select { |f| f['f'] }.first
    return pad_with_underscores('', 15) if f245.nil?

    subff = f245['f'].dup
    subff = normalize_string_and_remove_accents(subff)
    subff = strip_punctuation(string: subff)
    subff.downcase!
    pad_with_underscores(subff, 15)
  end

  def get_gov_doc_key(record)
    f086 = record.fields('086').select { |f| f['a'] }.first
    return '' if f086.nil?

    subfa = f086['a'].dup
    subfa = normalize_string_and_remove_accents(subfa)
    subfa = strip_punctuation(string: subfa)
    subfa.downcase!
    trim_max_field_length(subfa)
  end

  def get_match_key(record)
    match_key = get_title_key(record)
    match_key << get_pub_date_key(record)
    match_key << get_pagination_key(record)
    match_key << get_edition_key(record)
    match_key << get_publisher_key(record)
    match_key << get_type_key(record)
    match_key << get_title_part_key(record)
    match_key << get_title_number_key(record)
    match_key << get_author_key(record)
    match_key << get_title_date_key(record)
    match_key << get_gov_doc_key(record)
    match_key << get_format_character(record)
    match_key
  end
end
