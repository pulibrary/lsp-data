# frozen_string_literal: true

require_relative './../lib/lsp-data'

### Helper method to map 019 $a values to the OCLC number found in the 035$a of
###   an OCLC record; return nil if there is no 019 field
def oclc_xrefs(record)
  f019 = record.fields('019')
  return [] if f019.empty?

  xrefs = []
  record.fields('019').each do |field|
    field.subfields.each do |subfield|
      xrefs << subfield.value if subfield.code == 'a'
    end
  end
  xrefs
end

def construct_035_oclc(oclc_num:, xrefs: [])
  field = MARC::DataField.new('035', ' ', ' ')
  field.append(MARC::Subfield.new('a', "(OCoLC)#{oclc_num}"))
  xrefs.each do |xref|
    field.append(MARC::Subfield.new('z', "(OCoLC)#{xref}"))
  end
  field
end

def make_brief_record(record:, xrefs:, oclc_num:)
  record.fields.select! { |f| %w[001 035 245].include?(f.tag) }
  record.fields.delete_if { |f| f.tag == '035' && f.to_s =~ /OCoLC/ }
  new_field = construct_035_oclc(oclc_num: oclc_num, xrefs: xrefs)
  record.append(new_field)
  record
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

oclc_old_to_new = {} # 035$z from OCLC mapped to 035$a
oclc_new_to_old = {} # Used to generate xrefs for PUL records
File.open("#{output_dir}/all_oclc_oclc_numbers.txt", 'w') do |output|
  Dir.glob("#{input_dir}/oclc_dump/meta*.mrc").each do |file|
    reader = MARC::Reader.new(file)
    reader.each do |record|
      oclc_num = oclcs(record: record).first
      output.puts(oclc_num)
      xrefs = oclc_xrefs(record)
      xrefs.each do |xref|
        oclc_old_to_new[xref] = oclc_num
        oclc_new_to_old[oclc_num] ||= []
        oclc_new_to_old[oclc_num] << xref
      end
    end
  end
end

### If a record in Alma has multiple OCLC numbers in 035$a that don't resolve
###   to the same canonical OCLC number, do not consider it
###   a candidate for updating xrefs
### Write out records that have xrefs for OCLC numbers with a new 035
###   with the canonical OCLC number in 035$a with just (OCoLC),
###   and all xrefs as 035$z; remove the old OCLC numbers in 035 fields;
###   the records should only have 001, all 035 fields, and a 245
fname = 'pul_records_xref_as_oclc'
fnum = 0
rec_num = 0
writer = nil
File.open("#{output_dir}/all_pul_oclc_numbers.txt", 'w') do |output|
  Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
    reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
    reader.each do |record|
      oclc_nums = oclcs(record: record)
      actual_oclc_nums = []
      oclc_nums.each do |num|
        actual_oclc_nums << (oclc_old_to_new[num] || num)
      end
      actual_oclc_nums.uniq!
      actual_oclc_nums.each { |oclc_num| output.puts(oclc_num) }
      next if actual_oclc_nums.size != 1
      next if (oclc_nums & actual_oclc_nums) == oclc_nums

      xrefs = oclc_new_to_old[actual_oclc_nums.first]
      next unless xrefs

      if (rec_num % 100_000).zero?
        writer&.close
        fnum += 1
        writer = MARC::XMLWriter.new("#{output_dir}/#{fname}_#{fnum}.marcxml")
      end
      brief_record = make_brief_record(record: record, oclc_num: actual_oclc_nums.first, xrefs: xrefs)
      writer.write(brief_record)
      rec_num += 1
    end
  end
end
writer.close
oclc_old_to_new.clear
oclc_new_to_old.clear
### OCLC reconciliation: Find unique OCLC numbers in both sets, and the overlap
oclc_oclc_nums = Set.new
File.open("#{input_dir}/all_oclc_oclc_numbers.txt", 'r') do |input|
  while (line = input.gets)
    line.chomp!
    oclc_oclc_nums << line
  end
end
pul_oclc_nums = Set.new
Dir.glob("#{input_dir}/all_pul_oclc_number*.txt").each do |file|
  File.open(file, 'r') do |input|
    while (line = input.gets)
      line.chomp!
      pul_oclc_nums << line
    end
  end
end

oclc_only = oclc_oclc_nums - pul_oclc_nums
File.open("#{output_dir}/oclc_nums_to_unset.txt", 'w') do |output|
  output.puts('OCLC Number')
  oclc_only.each { |num| output.puts(num) }
end

### Unset the holdings using the OCLC metadata API
client_id = ENV['METADATA_API_ID']
client_secret = ENV['METADATA_API_SECRET']
scope = 'WorldCatMetadataAPI'
oauth = OAuth.new(client_id: client_id,
                      client_secret: client_secret,
                      url: OCLC_OAUTH_ENDPOINT,
                      scope: scope)
oauth_response = oauth.response
conn = LspData.api_conn(METADATA_API_ENDPOINT)
responses = {}

oclc_only.each do |oclc_num|
  next if responses[oclc_num]

  if Time.now > (oauth_response[:expiration] - 60)
    oauth = OAuth.new(client_id: client_id,
                          client_secret: client_secret,
                          url: token_url,
                          scope: scope)
    oauth_response = oauth.response
  end
  unset_action = OCLCUnset.new(oclc_num: oclc_num,
                               token: oauth_response[:token],
                               conn: conn)
  responses[oclc_num] = { status: unset_action.status,
                          message: unset_action.message }
end

File.open("#{output_dir}/unset_responses.tsv", 'w') do |output|
  output.puts("OCLC Number\tStatus Code\tMessage")
  responses.each do |oclc_num, info|
    output.write("#{oclc_num}\t")
    output.write("#{info[:status]}")
    output.puts(info[:message]['message'])
  end
end
