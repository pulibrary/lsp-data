# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'csv'
### I’m trying to get an e-book of a title we already own in physical format.
### It’s only available if we buy at least 3 e-book titles at the same time.
### The vendor sent a list of options (attached) for other titles to buy,
### but I don't have time to search individually and figure out which ones we
### already have or not. From this spreadsheet, I'd like to know which ones
### we don't own, which ones we do own, and what format we own (print, ebook, or both).
### I'm mostly interested in books dealing with music, dance, and theater
###   (see subjects in columns R-T), if you need to narrow down the report. Thank you!

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

csv = CSV.open("#{input_dir}/ecollection options_book_metadata.csv", 'r', headers: true, encoding: 'bom|utf-8')
target_isbns = csv.map { |row| row['Primary ISBN'] }.uniq

matches = {} # isbn to MMS ID; within the MMS ID, indicate print or electronic holdings
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next if record.leader[5] == 'd'

    isbn_matches = isbns(record).select { |isbn| target_isbns.include?(isbn) }
    mms_id = record['001'].value
    physical = record.fields('852').any? { |f| f['8'] =~ /^22[0-9]+6421$/ }
    electronic = record.fields('951').any? { |f| f['0'] =~ /6421$/ }
    isbn_matches.each do |isbn|
      matches[isbn] ||= {}
      matches[isbn][mms_id] = { physical: physical, electronic: electronic }
    end
  end
end

File.open("#{output_dir}/read_report_task0415257.tsv", 'w') do |output|
  output.write("Title\tSubtitle\tSeries Title\tContributors\t")
  output.write("Publisher\tURL\tBook ID\tPrimary ISBN\tOCLC\tMUSE Launch Date\t")
  output.write("Publication Year\tSingle Title Purchase\tOpen Access\t")
  output.write("Language\tCountry\tDiscipline 1\tDiscipline 2\tDiscipline 3\t")
  output.write("Complete Collections\tSubject Collections\tArea Studies Collections\t")
  output.puts("Series Collections\tPUL Print MMS IDs\tPUL Electronic MMS IDs")
  csv = CSV.open("#{input_dir}/ecollection options_book_metadata.csv", 'r', headers: true, encoding: 'bom|utf-8')
  csv.each do |row|
    isbn = row['Primary ISBN']
    row.each do |header, info|
      next if ['Content Type', 'Available on MUSE', 'The Complete Prose Of T.S. Eliot'].include?(header)

      output.write("#{info}\t")
    end
    pul_matches = matches[isbn]
    if pul_matches
      electronic_bibs = pul_matches.select { |_mms_id, types| types[:electronic] }.keys
      print_bibs = pul_matches.select { |_mms_id, types| types[:physical] }.keys
      output.write("#{print_bibs.join(' | ')}\t")
      output.puts(electronic_bibs.join(' | '))
    else
      output.puts("\t")
    end
  end
end
