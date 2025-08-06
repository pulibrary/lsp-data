# frozen_string_literal: true

require_relative './../lib/lsp-data'

def dixon_record?(record)
  record.fields('852').any? do |field|
    field['8'] =~ /^22.*6421$/ &&
      field['b'] == 'firestone' &&
      field['c'] == 'dixn'
  end
end

def title_from_field(field)
  return scrub_string(field['a']) if field['a']

  targets = title_field.subfields.reject { |subfield| subfield.code == '6' }
  c_index = targets.index { |subfield| subfield.code == 'c' }
  c_index ||= -1
  title_string = targets[0..c_index].map(&:value).join(' ')
  scrub_string(title_string)
end

def title(record)
  f880_title_field = record.fields('880').find { |field| field['6'] && field['6'] =~ /^245/ }
  if f880_title_field
    title_from_field(f880_title_field)
  else
    title_field = record['245']
    title_from_field(title_field)
  end
end

def info_from_f008(record)
  f008 = record['008']
  return unless f008

  { date1: f008.value[7..10], pub_place: f008.value[15..17] }
end

def publisher_info_from_field(field)
  pub_place = scrub_string(field['a'])
  pub_name = scrub_string(field['b'])
  pub_date = scrub_string(field['c'])
  { pub_place: pub_place, pub_name: pub_name, pub_date: pub_date }
end

def publisher_info(record)
  f260 = record['260']
  return publisher_info_from_field(f260) if f260

  f264 = record.fields('264').min_by(&:indicator2)
  if f264
    publisher_info_from_field(f264)
  else
    { pub_place: nil, pub_name: nil, pub_date: nil }
  end
end

def author_subfields_to_skip(field_tag)
  case field_tag
  when '100', '110'
    %w[0 1 6 e]
  else
    %w[0 1 6 j]
  end
end

def author(record)
  auth_field = record.fields(%w[100 110 111]).first
  return unless auth_field

  subf_to_skip = author_subfields_to_skip(auth_field.tag)
  author_string = auth_field.subfields.reject do |subfield|
    subf_to_skip.include?(subfield.code)
  end.map(&:value)
     .join(' ')
  scrub_string(author_string)
end

def imprint_fields(record)
  target_fields = record.fields('250'..'259')
  return [] if target_fields.empty?

  fields = []
  target_fields.each do |field|
    tag = field.tag
    text = field.subfields.map(&:value).join(' ')
    fields << { tag: tag, text: scrub_string(text) }
  end
  fields
end

def scrub_string(string)
  return unless string

  new_string = string.dup.strip
  new_string[-1] = '' if new_string[-1] =~ %r{[.,:/=]}
  new_string.strip.gsub(/(\s){2, }/, '\1')
end

def info_for_dixon_record(record)
  {
    isbns: isbns(record),
    oclcs: oclcs(record: record),
    title: title(record),
    author: author(record),
    f008: info_from_f008(record),
    format: record.leader[6..7],
    publisher_info: publisher_info(record),
    imprint_fields: imprint_fields(record)
  }
end

### Create 2 hashes: one for unsuppressed bibs with a location of firestone$dixn
###   and one for unsuppressed bibs with electronic inventory with match key as the key
### The hash for the Dixon books will include the following for each bib:
###   MMS ID
###   Title
###   Author
###   Format (from the leader)
###   Date1 from 008
###   Publication Date from 260/264
###   Publisher
###   Place of publication from 008
###   Place of publication from 260/264
###   Edition statement
###   ISBNs
###   OCLC Numbers

### The hash for the electronic books will only have the MMS IDs
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

dixon = {}
electronic = {}
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd'

    match_key = MarcMatchKey::Key.new(record).key
    mms_id = record['001'].value
    if dixon_record?(record)
      dixon[match_key] ||= {}
      dixon[match_key][mms_id] = info_for_dixon_record(record)
    elsif record.fields('951').any? { |f| f['8'] =~ /^53[0-9]+6421$/ }
      electronic[match_key] ||= []
      electronic[match_key] << mms_id
    end
  end
end

### Step 2: Produce report with the following information:
###  All info from the Dixon record
###  MMS IDs of electronic records
File.open("#{output_dir}/logan_report_dixon.tsv", 'w') do |output|
  output.write("Match Key\tDixon MMS ID\tBib Format\tTitle\tAuthor\t")
  output.write("008 Pub Date\t008 Pub Place\tPublication Date\tPublication Place\tPublisher\t")
  output.puts("Imprint Statements\tISBNs\tOCLC Numbers\tMMS IDs of Electronic Matches")
  dixon.each do |match_key, bibs|
    e_bibs = electronic[match_key]
    bibs.each do |mms_id, info|
      output.write("#{match_key}\t#{mms_id}\t#{info[:format]}\t#{info[:title]}\t#{info[:author]}\t")
      if info[:f008]
        output.write("#{info[:f008][:date1]}\t#{info[:f008][:pub_place]}\t")
      else
        output.write("\t\t")
      end
      output.write("#{info[:publisher_info][:pub_date]}\t")
      output.write("#{info[:publisher_info][:pub_place]}\t")
      output.write("#{info[:publisher_info][:pub_name]}\t")
      imprint_field_strings = info[:imprint_fields]
      output.write("#{imprint_field_strings.map { |f| f[:text] }.join(' | ')}\t")
      output.write("#{info[:isbns].join(' | ')}\t#{info[:oclcs].join(' | ')}\t")
      if e_bibs
        output.puts(e_bibs.join(' | '))
      else
        output.puts('')
      end
    end
  end
end
