# frozen_string_literal: true

require_relative '../lib/lsp-data'

def lcsh?(record)
  lcsh_fields = %w[600 610 611 630 647 648 650 651]
  record.fields(lcsh_fields).any? { |field| field.indicator2 == '0' } ||
    record.fields('655').any? { |field| %w[lcgft aat].include?(field['2']) }
end

def cotsen?(record)
  cotsen_locations = %w[rare$ctsn rare$ctsnrf rare$hsvc rare$scactsn rare$scahsvc rare$xc rare$xcr]
  record.fields('852').any? do |field|
    field['8'] =~ /^22[0-9]+6421$/ &&
      cotsen_locations.include?([field['b'], field['c']].join('$'))
  end
end

def print_noncotsen?(record)
  cotsen_locations = %w[rare$ctsn rare$ctsnrf rare$hsvc rare$scactsn rare$scahsvc rare$xc rare$xcr]
  record.fields('852').any? do |field|
    field['8'] =~ /^22[0-9]+6421$/ &&
      !cotsen_locations.include?([field['b'], field['c']].join('$'))
  end
end

def locations(mms_id:, record:, constituent_to_host:, host_to_locations:)
  location_fields = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
  locations = location_fields.map { |field| [field['b'], field['c']].join('$') }
  constituent_to_host[mms_id]&.each do |host_id|
    locations += host_to_locations[host_id] if host_to_locations[host_id]
  end
  locations.uniq
end

def electronic?(locations, record)
  locations.empty? && record.fields('951').any? do |field|
    field['0'] =~ /6421$/ && field['a'] == 'Available'
  end
end

def record_type(record, constituent_to_host, host_to_locations)
  mms_id = record['001'].value
  locations = locations(mms_id: mms_id, record: record, constituent_to_host: constituent_to_host,
                        host_to_locations: host_to_locations)
  return 'electronic' if electronic?(locations, record)
  return 'cotsen|print' if cotsen?(record) && print_noncotsen?(record)
  return 'cotsen' if cotsen?(record)
  return 'print' if print_noncotsen?(record)

  'no_inventory'
end

input_dir = ENV.fetch('DATA_INPUT_DIR', nil)
output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)

### Go through a full dump to find all host records and their constituent IDs;
### Write out records that have 653 fields
writer = MARC::XMLWriter.new("#{output_dir}/records_with_653_fields.marcxml")
constituent_to_host = {} # constituent ID to all hosts
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  puts File.basename(file)
  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next if record.leader[5] == 'd'

    writer.write(record) if record['653']
    next unless record.fields('773').any? { |field| field['w'] =~ /^99[0-9]+6421$/ }

    mms_id = record['001'].value
    record.fields('773').select { |field| field['w'] =~ /^99[0-9]+6421$/ }.each do |field|
      constituent_to_host[mms_id] ||= []
      constituent_to_host[mms_id] << field['w']
    end
  end
end
writer.close

### Go through a full dump again, getting the locations for the host IDs
all_host_ids = Set.new(constituent_to_host.values.flatten)
host_to_locations = {}
Dir.glob("#{input_dir}/new_fulldump/fulldump*.xml*").each do |file|
  break if host_to_locations.size == all_host_ids.size

  MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true).each do |record|
    next if record.leader[5] == 'd'

    mms_id = record['001'].value
    next unless all_host_ids.include?(mms_id)

    location_fields = record.fields('852').select { |field| field['8'] =~ /^22[0-9]+6421$/ }
    locations = location_fields.map { |field| [field['b'], field['c']].join('$') }.uniq
    host_to_locations[mms_id] = locations
  end
end

### Produce report of 653 field values [subfield text only];
### Include a record type (cotsen; print; electronic; no_inventory; cotsen|print if both conditions apply)
file_date = Time.new.strftime('%Y-%m-%d')
print_output = File.open("#{output_dir}/653_report_print_#{file_date}.tsv", 'w')
cotsen_output = File.open("#{output_dir}/653_report_cotsen_#{file_date}.tsv", 'w')
print_cotsen_output = File.open("#{output_dir}/653_report_printcotsen_#{file_date}.tsv", 'w')
electronic_output = File.open("#{output_dir}/653_report_electronic_#{file_date}.tsv", 'w')
other_output = File.open("#{output_dir}/653_report_no_inventory_#{file_date}.tsv", 'w')
header_row = "653 Field\tMMS ID\tHas LCSH?"
print_output.puts(header_row)
cotsen_output.puts(header_row)
print_cotsen_output.puts(header_row)
electronic_output.puts(header_row)
other_output.puts(header_row)
MARC::XMLReader.new("#{input_dir}/records_with_653_fields.marcxml", parser: 'magic',
                                                                    ignore_namespace: true).each do |record|
  next if record.leader[5] == 'd'

  mms_id = record['001'].value
  record_type = record_type(record, constituent_to_host, host_to_locations)
  lcsh = lcsh?(record)
  record.fields('653').each do |field|
    field_value = field.subfields.map(&:value).join(' ')
    case record_type
    when 'electronic'
      electronic_output.puts("#{field_value}\t#{mms_id}\t#{lcsh}")
    when 'cotsen'
      cotsen_output.puts("#{field_value}\t#{mms_id}\t#{lcsh}")
    when 'print'
      print_output.puts("#{field_value}\t#{mms_id}\t#{lcsh}")
    when 'cotsen|print'
      print_cotsen_output.puts("#{field_value}\t#{mms_id}\t#{lcsh}")
    when 'no_inventory'
      other_output.puts("#{field_value}\t#{mms_id}\t#{lcsh}")
    end
  end
end
print_output.close
cotsen_output.close
print_cotsen_output.close
electronic_output.close
other_output.close

### There are too many headings in e-resource records to show one row per MMS ID
File.open("#{output_dir}/653_report_electronic_summary_#{file_date}.tsv", 'w') do |output|
  output.puts("653 Field\tMMS IDs\tCount of MMS IDs\tHas LCSH?")
  field_lcsh_mms_count = {}
  File.open("#{input_dir}/653_report_electronic_#{file_date}.tsv", 'r') do |input|
    input.gets
    while (line = input.gets)
      line.chomp!
      parts = line.split("\t")
      field_lcsh_mms_count[parts[0]] ||= { lcsh: [], non_lcsh: [] }
      case parts[2]
      when 'true'
        field_lcsh_mms_count[parts[0]][:lcsh] << parts[1]
      else
        field_lcsh_mms_count[parts[0]][:non_lcsh] << parts[1]
      end
    end
  end
  field_lcsh_mms_count.each do |heading, types|
    output.puts("#{heading}\t#{types[:lcsh].join(' |')}\t#{types[:lcsh].size}\tTRUE") if types[:lcsh].size.positive?
    if types[:non_lcsh].size.positive?
      output.puts("#{heading}\t#{types[:non_lcsh].join(' | ')}\t#{types[:non_lcsh].size}\tFALSE")
    end
  end
end

### Produce summary report that shows how many MMS IDs per record type there are for each heading
field_lcsh_type_count = {}
File.open("#{output_dir}/653_report_print_#{file_date}.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    field_lcsh_type_count[parts[0]] ||= {}
    field_lcsh_type_count[parts[0]][:lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                 'cotsen' => [], 'electronic' => [],
                                                 'no_inventory' => [] }
    field_lcsh_type_count[parts[0]][:non_lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                     'cotsen' => [], 'electronic' => [],
                                                     'no_inventory' => [] }
    case parts[2] # whether has LCSH
    when 'true'
      field_lcsh_type_count[parts[0]][:lcsh]['print'] << parts[1]
    else
      field_lcsh_type_count[parts[0]][:non_lcsh]['print'] << parts[1]
    end
  end
end
File.open("#{output_dir}/653_report_cotsen_#{file_date}.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    field_lcsh_type_count[parts[0]] ||= {}
    field_lcsh_type_count[parts[0]][:lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                 'cotsen' => [], 'electronic' => [],
                                                 'no_inventory' => [] }
    field_lcsh_type_count[parts[0]][:non_lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                     'cotsen' => [], 'electronic' => [],
                                                     'no_inventory' => [] }
    case parts[2] # whether has LCSH
    when 'true'
      field_lcsh_type_count[parts[0]][:lcsh]['cotsen'] << parts[1]
    else
      field_lcsh_type_count[parts[0]][:non_lcsh]['cotsen'] << parts[1]
    end
  end
end
File.open("#{output_dir}/653_report_printcotsen_#{file_date}.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    field_lcsh_type_count[parts[0]] ||= {}
    field_lcsh_type_count[parts[0]][:lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                 'cotsen' => [], 'electronic' => [],
                                                 'no_inventory' => [] }
    field_lcsh_type_count[parts[0]][:non_lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                     'cotsen' => [], 'electronic' => [],
                                                     'no_inventory' => [] }
    case parts[2] # whether has LCSH
    when 'true'
      field_lcsh_type_count[parts[0]][:lcsh]['print_cotsen'] << parts[1]
    else
      field_lcsh_type_count[parts[0]][:non_lcsh]['print_cotsen'] << parts[1]
    end
  end
end
File.open("#{output_dir}/653_report_electronic_#{file_date}.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    field_lcsh_type_count[parts[0]] ||= {}
    field_lcsh_type_count[parts[0]][:lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                 'cotsen' => [], 'electronic' => [],
                                                 'no_inventory' => [] }
    field_lcsh_type_count[parts[0]][:non_lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                     'cotsen' => [], 'electronic' => [],
                                                     'no_inventory' => [] }
    case parts[2] # whether has LCSH
    when 'true'
      field_lcsh_type_count[parts[0]][:lcsh]['electronic'] << parts[1]
    else
      field_lcsh_type_count[parts[0]][:non_lcsh]['electronic'] << parts[1]
    end
  end
end
File.open("#{output_dir}/653_report_no_inventory_#{file_date}.tsv", 'r') do |input|
  input.gets
  while (line = input.gets)
    line.chomp!
    parts = line.split("\t")
    field_lcsh_type_count[parts[0]] ||= {}
    field_lcsh_type_count[parts[0]][:lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                 'cotsen' => [], 'electronic' => [],
                                                 'no_inventory' => [] }
    field_lcsh_type_count[parts[0]][:non_lcsh] ||= { 'print' => [], 'print_cotsen' => [],
                                                     'cotsen' => [], 'electronic' => [],
                                                     'no_inventory' => [] }
    case parts[2] # whether has LCSH
    when 'true'
      field_lcsh_type_count[parts[0]][:lcsh]['no_inventory'] << parts[1]
    else
      field_lcsh_type_count[parts[0]][:non_lcsh]['no_inventory'] << parts[1]
    end
  end
end
output = File.open("#{output_dir}/653_report_heading_summary_#{file_date}.tsv", 'w')
output.puts("653 Field\tHas LCSH?\tType\tTotal Records")
field_lcsh_type_count.each do |heading, info|
  output.puts("#{heading}\tTRUE\tPrint\t#{info[:lcsh]['print'].size}") if info[:lcsh]['print'].size.positive?
  output.puts("#{heading}\tFALSE\tPrint\t#{info[:non_lcsh]['print'].size}") if info[:non_lcsh]['print'].size.positive?
  output.puts("#{heading}\tTRUE\tCotsen\t#{info[:lcsh]['cotsen'].size}") if info[:lcsh]['cotsen'].size.positive?
  if info[:non_lcsh]['cotsen'].size.positive?
    output.puts("#{heading}\tFALSE\tCotsen\t#{info[:non_lcsh]['cotsen'].size}")
  end
  if info[:lcsh]['print_cotsen'].size.positive?
    output.puts("#{heading}\tTRUE\tPrint And Cotsen\t#{info[:lcsh]['print_cotsen'].size}")
  end
  if info[:non_lcsh]['print_cotsen'].size.positive?
    output.puts("#{heading}\tFALSE\tPrint And Cotsen\t#{info[:non_lcsh]['print_cotsen'].size}")
  end
  if info[:lcsh]['electronic'].size.positive?
    output.puts("#{heading}\tTRUE\tElectronic\t#{info[:lcsh]['electronic'].size}")
  end
  if info[:non_lcsh]['electronic'].size.positive?
    output.puts("#{heading}\tFALSE\tElectronic\t#{info[:non_lcsh]['electronic'].size}")
  end
  if info[:lcsh]['no_inventory'].size.positive?
    output.puts("#{heading}\tTRUE\tNo Inventory\t#{info[:lcsh]['no_inventory'].size}")
  end
  if info[:non_lcsh]['no_inventory'].size.positive?
    output.puts("#{heading}\tFALSE\tNo Inventory\t#{info[:non_lcsh]['no_inventory'].size}")
  end
end
output.close
