# frozen_string_literal: true

### For open orders on the general Slavic fund, find matches in ReCAP partners
### Since most open orders are continuations, GoldRush is less useful.
### Find matches based on ISSN or OCLC number in SCSB records.

### Requirements:
###   All info from the Open Orders report
###   SCSB IDs of matches, along with CGD and Use Restrictions
require_relative './../lib/lsp-data'
require 'bigdecimal'
require 'csv'

def cgd_for_pul_location(location)
  if %w[pa gp qk pf pv].include?(location)
    'Shared'
  else
    'Private'
  end
end

def use_restriction(location)
  case location[0..1]
  when 'pj', 'pk', 'pl', 'pm', 'pn', 'pt', 'pv'
    'In Library Use'
  when 'pb', 'ph', 'ps', 'pw', 'pz', 'xc', 'xg', 'xm', 'xn', 'xp', 'xr', 'xw', 'xx'
    'Supervised Use'
  end
end

def items_from_scsb_record(record)
  record.fields('876').map { |field| "#{field['l']}$#{field['z']} #{field['x']} #{field['h']}".strip }
end

input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']

### Step 1: Load open order report from Analytics;
###   Group the rows by MMS ID since there could be multiple locations

orders_by_bib = {}
csv = CSV.open("#{input_dir}/1762 Update to Keenan Report.csv", 'r', encoding: 'bom|utf-8', headers: true)
csv.each do |row|
  mms_id = row['mmsid']
  orders_by_bib[mms_id] ||= {}
  orders_by_bib[mms_id][:description] ||= row['item_des']
  orders_by_bib[mms_id][:issn] ||= issn_normalize(row['issn'].to_s)
  orders_by_bib[mms_id][:oclc] ||= oclc_normalize(oclc: row['oclc'].to_s, input_prefix: false, output_prefix: false)
  all_isbns = row['isbn'].to_s.split('; ').map { |isbn| isbn_normalize(isbn) }
  all_isbns.delete(nil)
  orders_by_bib[mms_id][:isbn] ||= all_isbns
  orders_by_bib[mms_id][:lc_class] ||= row['lc_class']
  orders_by_bib[mms_id][:lang_code] ||= row['lang_code']
  orders_by_bib[mms_id][:pub_name] ||= row['pub']
  orders_by_bib[mms_id][:lc_class_code] ||= row['lc_class_code']
  orders_by_bib[mms_id][:pub_place] ||= row['pub_place']
  orders_by_bib[mms_id][:pub_state] ||= row['pub_state']
  orders_by_bib[mms_id][:pub_country] ||= row['pub_country']
  orders_by_bib[mms_id][:locations] ||= Set.new
  orders_by_bib[mms_id][:locations] << { lib_code: row['lib_code'],
                                         loc_code: row['loc_code'],
                                         cgd: cgd_for_pul_location(row['loc_code']),
                                         use_restriction: use_restriction(row['loc_code']) }
  pol = row['pol']
  orders_by_bib[mms_id][:pols] ||= {}
  orders_by_bib[mms_id][:pols][pol] ||= {}
  orders_by_bib[mms_id][:pols][pol][:vendor_code] ||= row['vend_cd']
  orders_by_bib[mms_id][:pols][pol][:reporting_code] ||= row['rep_code']
  orders_by_bib[mms_id][:pols][pol][:invoice_status] ||= row['inv_stat']
  orders_by_bib[mms_id][:pols][pol][:line_type] ||= row['ord_line_ty']
  orders_by_bib[mms_id][:pols][pol][:vendor_account_code] ||= row['vend_acct_cd']
  orders_by_bib[mms_id][:pols][pol][:vendor_account_desc] ||= row['vend_acct_des']
  orders_by_bib[mms_id][:pols][pol][:net_price] ||= BigDecimal(row['net_price'])
  orders_by_bib[mms_id][:pols][pol][:currency] ||= row['curr']
  orders_by_bib[mms_id][:pols][pol][:pol_status] ||= row['stat_act']
  orders_by_bib[mms_id][:pols][pol][:encumbrance] ||= BigDecimal(row['trans_encum_amt'])
  orders_by_bib[mms_id][:pols][pol][:pol_create_date] ||= row['pol_create_date']
end

oclc_to_mms = {}
orders_by_bib.each do |id, info|
  oclc_num = info[:oclc]
  if oclc_num
    oclc_to_mms[oclc_num] = id
  end
end; nil
### Step 2: Find matches in ReCAP based on OCLC number first;
###   will only try matching on ISSN if the bib has no matches from this method

all_oclc = oclc_to_mms.keys
mms_to_scsb = {}
Dir.glob("#{input_dir}/partners/cul/CUL_20250421_095200/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclcs = oclcs(record: record,
                  input_prefix: true,
                  output_prefix: false)
    next if oclcs.empty?

    matches = oclcs & all_oclc
    matches.each do |oclc_num|
      mms_id = oclc_to_mms[oclc_num]
      mms_to_scsb[mms_id] ||= []
      mms_to_scsb[mms_id] << record
    end
  end
end; nil
Dir.glob("#{input_dir}/partners/cul/CUL_20250415_070000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclcs = oclcs(record: record,
                  input_prefix: true,
                  output_prefix: false)
    next if oclcs.empty?

    matches = oclcs & all_oclc
    matches.each do |oclc_num|
      mms_id = oclc_to_mms[oclc_num]
      mms_to_scsb[mms_id] ||= []
      mms_to_scsb[mms_id] << record
    end
  end
end; nil

Dir.glob("#{input_dir}/partners/hl/HL_20250421_091500/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclcs = oclcs(record: record,
                  input_prefix: true,
                  output_prefix: false)
    next if oclcs.empty?

    matches = oclcs & all_oclc
    matches.each do |oclc_num|
      mms_id = oclc_to_mms[oclc_num]
      mms_to_scsb[mms_id] ||= []
      mms_to_scsb[mms_id] << record
    end
  end
end; nil
Dir.glob("#{input_dir}/partners/hl/HL_20250415_230000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclcs = oclcs(record: record,
                  input_prefix: true,
                  output_prefix: false)
    next if oclcs.empty?

    matches = oclcs & all_oclc
    matches.each do |oclc_num|
      mms_id = oclc_to_mms[oclc_num]
      mms_to_scsb[mms_id] ||= []
      mms_to_scsb[mms_id] << record
    end
  end
end; nil

Dir.glob("#{input_dir}/partners/nypl/NYPL_20250415_150000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclcs = oclcs(record: record,
                  input_prefix: true,
                  output_prefix: false)
    next if oclcs.empty?

    matches = oclcs & all_oclc
    matches.each do |oclc_num|
      mms_id = oclc_to_mms[oclc_num]
      mms_to_scsb[mms_id] ||= []
      mms_to_scsb[mms_id] << record
    end
  end
end
Dir.glob("#{input_dir}/partners/cul/NYPL_20250421_101000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    oclcs = oclcs(record: record,
                  input_prefix: true,
                  output_prefix: false)
    next if oclcs.empty?

    matches = oclcs & all_oclc
    matches.each do |oclc_num|
      mms_id = oclc_to_mms[oclc_num]
      mms_to_scsb[mms_id] ||= []
      mms_to_scsb[mms_id] << record
    end
  end
end

### Step 3: Match on ISSN or ISBN for bibs that have no matches
issn_to_mms = {}
isbn_to_mms = {}
orders_by_bib.each do |id, info|
  next if mms_to_scsb[id]

  if info[:issn]
    issn_to_mms[info[:issn]] ||= []
    issn_to_mms[info[:issn]] << id
  end
  if info[:isbn].size.positive?
    info[:isbn].each do |isbn|
      isbn_to_mms[isbn] ||= []
      isbn_to_mms[isbn] << id
    end
  end
end

all_issns = issn_to_mms.keys
all_isbns = isbn_to_mms.keys
Dir.glob("#{input_dir}/partners/cul/CUL_20250421_095200/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    isbns = isbns(record)
    issns = issns(record)
    next if (isbns + issns).empty?

    isbn_matches = all_isbns & isbns
    issn_matches = all_issns & issns

    isbn_matches.each do |isbn|
      mms_ids = isbn_to_mms[isbn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
    issn_matches.each do |issn|
      mms_ids = issn_to_mms[issn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
  end
end; nil
Dir.glob("#{input_dir}/partners/cul/CUL_20250415_070000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    isbns = isbns(record)
    issns = issns(record)
    next if (isbns + issns).empty?

    isbn_matches = all_isbns & isbns
    issn_matches = all_issns & issns

    isbn_matches.each do |isbn|
      mms_ids = isbn_to_mms[isbn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
    issn_matches.each do |issn|
      mms_ids = issn_to_mms[issn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
  end
end; nil

Dir.glob("#{input_dir}/partners/hl/HL_20250421_091500/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    isbns = isbns(record)
    issns = issns(record)
    next if (isbns + issns).empty?

    isbn_matches = all_isbns & isbns
    issn_matches = all_issns & issns

    isbn_matches.each do |isbn|
      mms_ids = isbn_to_mms[isbn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
    issn_matches.each do |issn|
      mms_ids = issn_to_mms[issn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
  end
end; nil
Dir.glob("#{input_dir}/partners/hl/HL_20250415_230000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    isbns = isbns(record)
    issns = issns(record)
    next if (isbns + issns).empty?

    isbn_matches = all_isbns & isbns
    issn_matches = all_issns & issns

    isbn_matches.each do |isbn|
      mms_ids = isbn_to_mms[isbn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
    issn_matches.each do |issn|
      mms_ids = issn_to_mms[issn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
  end
end; nil

Dir.glob("#{input_dir}/partners/nypl/NYPL_20250415_150000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    isbns = isbns(record)
    issns = issns(record)
    next if (isbns + issns).empty?

    isbn_matches = all_isbns & isbns
    issn_matches = all_issns & issns

    isbn_matches.each do |isbn|
      mms_ids = isbn_to_mms[isbn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
    issn_matches.each do |issn|
      mms_ids = issn_to_mms[issn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
  end
end; nil
Dir.glob("#{input_dir}/partners/nypl/NYPL_20250421_101000/*.xml").each do |file|
  puts File.basename(file)
  reader = MARC::XMLReader.new(file, parser: 'magic', ignore_namespace: true)
  reader.each do |record|
    isbns = isbns(record)
    issns = issns(record)
    next if (isbns + issns).empty?

    isbn_matches = all_isbns & isbns
    issn_matches = all_issns & issns

    isbn_matches.each do |isbn|
      mms_ids = isbn_to_mms[isbn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
    issn_matches.each do |issn|
      mms_ids = issn_to_mms[issn]
      mms_ids.each do |mms_id|
        mms_to_scsb[mms_id] ||= []
        mms_to_scsb[mms_id] << record
      end
    end
  end
end

### Write out report
File.open("#{output_dir}/keenan_open_orders_with_scsb_matches.tsv", 'w') do |output|
  output.write("POL\tPOL Line Type\tPOL Status\tPOL Invoice Status\t")
  output.write("Reporting Code\tVendor Code\tVendor Account Code\tVendor Account Description\t")
  output.write("Net Price\tPOL Currency\tCurrent Encumbrance\tPOL Create Date\t")
  output.write("Description\tISBNs\tISSN\tOCLC Number\tPUL MMS ID\t")
  output.write("LC Class\tLC Class Code\tLanguage Code\tPublisher Name\t")
  output.write("Publisher Place\tPublisher State\tPublisher Country\t")
  output.write("PUL Locations\tCUL IDs\tCUL Location Info\t")
  output.puts("HL IDs\tHL Location Info\tNYPL IDs\tNYPL Location Info\tAll Matched Institutions")
  orders_by_bib.each do |mms_id, info|
    info[:pols].each do |pol_id, pol_info|
      output.write("#{pol_id}\t")
      output.write("#{pol_info[:line_type]}\t")
      output.write("#{pol_info[:pol_status]}\t")
      output.write("#{pol_info[:invoice_status]}\t")
      output.write("#{pol_info[:reporting_code]}\t")
      output.write("#{pol_info[:vendor_code]}\t")
      output.write("#{pol_info[:vendor_account_code]}\t")
      output.write("#{pol_info[:vendor_account_desc]}\t")
      output.write("#{pol_info[:net_price].to_s('F')}\t")
      output.write("#{pol_info[:currency]}\t")
      output.write("#{pol_info[:encumbrance].to_s('F')}\t")
      output.write("#{pol_info[:pol_create_date]}\t")
      output.write("#{info[:description]}\t")
      output.write("#{info[:isbn].join(' | ')}\t")
      output.write("#{info[:issn]}\t")
      output.write("#{info[:oclc]}\t")
      output.write("#{mms_id}\t")
      output.write("#{info[:lc_class]}\t")
      output.write("#{info[:lc_class_code]}\t")
      output.write("#{info[:lang_code]}\t")
      output.write("#{info[:pub_name]}\t")
      output.write("#{info[:pub_place]}\t")
      output.write("#{info[:pub_state]}\t")
      output.write("#{info[:pub_country]}\t")
      location_blob = info[:locations].map { |info| "#{info[:lib_code]}$#{info[:loc_code]} #{info[:cgd]} #{info[:use_restriction]}"}
      output.write("#{location_blob.join(' | ')}\t")
      recap_matches = mms_to_scsb[mms_id]
      if recap_matches.nil?
        output.puts("\t\t\t\t\t\t")
      else
        cul_matches = recap_matches.select do |record|
          record.fields('852').any? { |field| field['b'] == 'scsbcul' }
        end
        cul_ids = cul_matches.map { |record| record['001'].value }
        cul_items = []
        cul_matches.each do |record|
          cul_items += items_from_scsb_record(record)
        end
        cul_items.uniq!
        output.write("#{cul_ids.join(' | ')}\t")
        output.write("#{cul_items.join(' | ')}\t")
        hl_matches = recap_matches.select do |record|
          record.fields('852').any? { |field| field['b'] == 'scsbhl' }
        end
        hl_ids = hl_matches.map { |record| record['001'].value }
        hl_items = []
        hl_matches.each do |record|
          hl_items += items_from_scsb_record(record)
        end
        hl_items.uniq!
        output.write("#{hl_ids.join(' | ')}\t")
        output.write("#{hl_items.join(' | ')}\t")
        nypl_matches = recap_matches.select do |record|
          record.fields('852').any? { |field| field['b'] == 'scsbnypl' }
        end
        nypl_ids = nypl_matches.map { |record| record['001'].value }
        nypl_items = []
        nypl_matches.each do |record|
          items = record.fields('876').map { |field| "#{field['l']}$#{field['z']} #{field['x']} #{field['h']}".strip }
          nypl_items += items_from_scsb_record(record)
        end
        nypl_items.uniq!
        output.write("#{nypl_ids.join(' | ')}\t")
        output.write("#{nypl_items.join(' | ')}\t")
        all_matches = ''.dup
        all_matches << 'CUL' if cul_matches.size.positive?
        all_matches << ' HL' if hl_matches.size.positive?
        all_matches << ' NYPL' if nypl_matches.size.positive?
        output.puts(all_matches)
      end
    end
  end
end
