# frozen_string_literal: true

require_relative '../lib/lsp-data'
### All records in Alma that have a 340 field.
###   I'm not expecting a large number, probably 1,500-5,000.
### Wanted fields: 340 value(s), MMS id, title, call no., location, 300, 008: date1, date2, lang

def eligible_record?(record)
  record['340'] && record.leader[5] != 'd'
end

def holding_call_num(holding)
  holding.subfields.select { |subfield| %w[h i].include?(subfield.code) }
         .map(&:value)
         .join(' ')
end
input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

output = File.open("#{output_dir}/bell_report_task0415447.tsv", 'w')
output.write("MMS ID\tTitle\tHolding ID\tLibrary\tLocation\tCall Number\t")
output.puts("Date1\tDate2\tLanguage\t300 Field\t340 Fields")
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    next unless eligible_record?(record)

    f340_blob = record.fields('340').map do |field|
      field.subfields.map(&:value).join(' ')
    end.join(' | ')
    f300_blob = record.fields('300').map do |field|
      field.subfields.map(&:value).join(' ')
    end.join(' | ')
    f852 = record.fields('852').select { |f| f['8'] =~ /^22[0-9]+6421$/ }
    f852.each do |holding|
      output.write("#{record['001'].value}\t")
      output.write("#{title(record)}\t")
      output.write("#{holding['8']}\t") # Holding ID
      output.write("#{holding['b']}\t") # Library code
      output.write("#{holding['c']}\t") # Location code
      output.write("#{holding_call_num(holding)}\t")
      output.write("#{record['008']&.value&.[](7..10)}\t") # Date1 from 008
      output.write("#{record['008']&.value&.[](11..14)}\t") # Date2 from 008
      output.write("#{record['008']&.value&.[](35..37)}\t") # Language
      output.write("#{f300_blob}\t")
      output.puts(f340_blob)
    end
  end
end
output.close
