# frozen_string_literal: true

require 'library_stdnums'
module LspData
  ### Get all library standard numbers from a MARC record;
  ###   default to requiring the OCLC prefix
  def standard_nums(record:, input_prefix: true, output_prefix: false)
    lccn = lccns(record)
    isbn = isbns(record)
    issn = issns(record)
    oclc = oclcs(record: record,
                 input_prefix: input_prefix,
                 output_prefix: output_prefix)
    { lccn: lccn, isbn: isbn, issn: issn, oclc: oclc }
  end

  def lccns(record)
    record.fields('010')
      .select { |f| f['a'] }
      .filter_map { |f| StdNum::LCCN.normalize(f['a']) }
      .uniq
  end

  def isbns(record)
    isbn = []
    f020 = record.fields('020').select { |f| f['a'] }
    f020.each do |field|
      value = isbn_normalize(field['a'])
      isbn << value if value
    end
    isbn.uniq
  end

  ### Convert ISBN-10 to ISBN-13
  def isbn10to13(isbn)
    stem = isbn[0..8]
    return nil if stem =~ /\D/

    existing_check = isbn[9]
    return nil if existing_check && existing_check != checkdigit_isbn10(stem)

    main = ISBN13PREFIX + stem
    checkdigit = checkdigit_isbn13(main)
    main + checkdigit
  end

  ### Calculate check digit for ISBN-10
  def checkdigit_isbn10(stem)
    int_sum = stem.chars
      .each_with_index
      .reduce(0) {|int_sum, (digit, int_index)| int_sum += digit.to_i * (10 - int_index) }
    mod = (11 - (int_sum % 11)) % 11
    mod == 10 ? 'X' : mod.to_s
  end

  ### Calculate check digit for ISBN-13
  def checkdigit_isbn13(stem)
    int_index = 0
    int_sum = 0
    stem.each_char do |digit|
      int_sum += int_index.even? ? digit.to_i : digit.to_i * 3
      int_index += 1
    end
    ((10 - (int_sum % 10)) % 10).to_s
  end

  ### Normalize ISBN-13
  def isbn13_normalize(raw_isbn)
    int_sum = 0
    stem = raw_isbn[0..11]
    return nil if stem =~ /\D/

    int_index = 0
    stem.each_char do |digit|
      int_sum += int_index.even? ? digit.to_i : digit.to_i * 3
      int_index += 1
    end
    checkdigit = checkdigit_isbn13(stem)
    return nil if raw_isbn[12] && raw_isbn[12] != checkdigit

    stem + checkdigit
  end

  def clean_isbn_string(isbn)
    isbn.delete!('-')
    isbn.delete!('\\')
    isbn.gsub!(/\([^)]*\)/, '')
    isbn.gsub!(/^(.*)\$c.*$/, '\1')
    isbn.gsub!(/^(.*)\$q.*$/, '\1')
    isbn.gsub!(/^\D+(\d.*)$/, '\1')
    if isbn =~ /^978/
      isbn.gsub!(/^(978[0-9 ]+).*$/, '\1')
      isbn.delete!(' ')
    else
      isbn.gsub!(/(\d)\s*(\d{4})\s*(\d{4})\s*([0-9xX]).*$/, '\1\2\3\4')
    end
    isbn.gsub!(/^(\d{9,13}[xX]?)[^0-9xX].*$/, '\1')
    isbn.gsub!(/^(\d+?)\D.*$/, '\1')
    isbn = isbn.ljust(9, '0') if isbn.length.between?(7, 8) && isbn =~ /^\d+$/
    isbn
  end

  ### Normalize any given string that is supposed to include an ISBN
  def isbn_normalize(isbn)
    return nil unless isbn

    raw_isbn = isbn.dup
    raw_isbn = clean_isbn_string(raw_isbn)
    return nil unless [9, 10, 12, 13].include?(raw_isbn.length)

    if raw_isbn.length < 12
      isbn10to13(raw_isbn)
    else
      isbn13_normalize(raw_isbn)
    end
  end

  ### 022$l is obsolete in favor of 023$a, but it still may appear
  def issns(record)
    issn = []
    issn_fields = record.fields('022'..'023')
    issn_fields.each do |field|
      field.subfields.each do |subfield|
        next unless %w[a l].include?(subfield.code)

        value = issn_normalize(subfield.value)
        issn << value if value
      end
    end
    issn.uniq
  end

  def clean_issn_string(issn)
    issn.delete!('-')
    issn.gsub!(/^\D+([0-9].*)$/, '\1')
    issn.gsub!(/^([0-9]{4})\s+([0-9xX]{4}).*$/, '\1\2')
    issn.gsub(/^([0-9]{7,}[^\s]+)\s.*$/, '\1')
  end

  ### Normalize any given string that is supposed to include an ISSN
  def issn_normalize(issn)
    raw_issn = issn.dup
    raw_issn = clean_issn_string(raw_issn)
    return nil unless raw_issn.length.between?(7, 8)

    stem = raw_issn[0..6]
    return nil if stem =~ /\D/

    int_sum = 0
    int_index = 0
    stem.each_char do |digit|
      int_sum += digit.to_i * (8 - int_index)
      int_index += 1
    end
    mod = (11 - (int_sum % 11)) % 11
    check_digit = mod == 10 ? 'X' : mod.to_s
    return nil if raw_issn[7] && raw_issn[7] != check_digit

    "#{stem[0..3]}-#{stem[4..6]}#{check_digit}"
  end

### Default to requiring an OCLC prefix of some kind in the field;
### default to stripping the correct OCLC prefix from the output
  def oclcs(record:, input_prefix: true, output_prefix: false)
    oclc = []
    f035 = record.fields('035').select { |f| f['a'] }
    f035.each do |field|
      value = oclc_normalize(oclc: field['a'],
                             input_prefix: input_prefix,
                             output_prefix: output_prefix)
      oclc << value if value
    end
    oclc.uniq
  end

  def add_prefix_to_oclc_num(oclc_num)
    case oclc_num.length
    when 1..8
      "(OCoLC)ocm#{format('%08d', oclc_num)}"
    when 9
      "(OCoLC)ocn#{oclc_num}"
    else
      "(OCoLC)on#{oclc_num}"
    end
  end

  ### Normalize OCLC numbers
  def oclc_normalize(oclc:, input_prefix:, output_prefix:)
    ### Do not process if there is a different prefix regardless of settings
    return nil if oclc.downcase =~ /\((?!ocolc)/
    return nil if input_prefix && !(oclc.downcase =~ /^\(ocolc\)/ ||
                                    oclc =~ /^ocn[0-9]|^ocm[0-9]|^on[0-9]/)

    oclc_num = oclc.gsub(/\D/, '').to_i.to_s
    return nil if oclc_num == '0'

    if output_prefix
      add_prefix_to_oclc_num(oclc_num)
    else
      oclc_num
    end
  end
end
