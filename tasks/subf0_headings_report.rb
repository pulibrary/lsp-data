require_relative './../lib/lsp-data'

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

subf0_counter = { cul: 0, nypl: 0, hl: 0 }
no_subf0_counter = { cul: 0, nypl: 0, hl: 0 }
### Goal: Find how many name headings have subfield zero, vs. how many don't
Dir.glob("#{input_dir}/partners/cul/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    name_fields = record.fields(%w[100 110 111 130 700 710 711 730])
    subf0_counter[:cul] += name_fields.select { |f| f['0'] =~ /loc\.gov/ }.size
    no_subf0_counter[:cul] += name_fields.select { |f| f['0'].nil? || f['0'] !~ /loc\.gov/ }.size
    subj_fields = record.fields(%w[600 610 611 630]).select { |f| f.indicator2 == '0' }
    subf0_counter[:cul] += subj_fields.select { |f| f['0'] =~ /loc\.gov/ }.size
    no_subf0_counter[:cul] += subj_fields.select { |f| f['0'].nil? || f['0'] !~ /loc\.gov/ }.size
  end
end

Dir.glob("#{input_dir}/partners/hl/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    name_fields = record.fields(%w[100 110 111 130 700 710 711 730])
    subf0_counter[:hl] += name_fields.select { |f| f['0'] =~ /loc\.gov/ }.size
    no_subf0_counter[:hl] += name_fields.select { |f| f['0'].nil? || f['0'] !~ /loc\.gov/ }.size
    subj_fields = record.fields(%w[600 610 611 630]).select { |f| f.indicator2 == '0' }
    subf0_counter[:hl] += subj_fields.select { |f| f['0'] =~ /loc\.gov/ }.size
    no_subf0_counter[:hl] += subj_fields.select { |f| f['0'].nil? || f['0'] !~ /loc\.gov/ }.size
  end
end

Dir.glob("#{input_dir}/partners/nypl/scsb_shared/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic')
  reader.each do |record|
    name_fields = record.fields(%w[100 110 111 130 700 710 711 730])
    subf0_counter[:nypl] += name_fields.select { |f| f['0'] =~ /loc\.gov/ }.size
    no_subf0_counter[:nypl] += name_fields.select { |f| f['0'].nil? || f['0'] !~ /loc\.gov/ }.size
    subj_fields = record.fields(%w[600 610 611 630]).select { |f| f.indicator2 == '0' }
    subf0_counter[:nypl] += subj_fields.select { |f| f['0'] =~ /loc\.gov/ }.size
    no_subf0_counter[:nypl] += subj_fields.select { |f| f['0'].nil? || f['0'] !~ /loc\.gov/ }.size
  end
end

File.open("#{output_dir}/heading_count.tsv", 'w') do |output|
  output.puts("Organization\tSubf0 headings\tNon-subf0 headings")
  output.puts("CUL\t#{subf0_counter[:cul]}\t#{no_subf0_counter[:cul]}")
  output.puts("HL\t#{subf0_counter[:hl]}\t#{no_subf0_counter[:hl]}")
  output.puts("NYPL\t#{subf0_counter[:nypl]}\t#{no_subf0_counter[:nypl]}")
end
