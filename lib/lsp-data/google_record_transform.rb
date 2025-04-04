# frozen_string_literal: true

module LspData
  ### This class transforms a record from Alma publishing into a record
  ###   that Google can ingest.
  ### Google is not interested in non-textual materials, so leader position 6
  ###   must be equal to `a`.
  ### Suppressed records should be excluded.
  ### Item and holding data should be in 955 fields, one per item
  ###   955$a is item PID [in case barcode changes in the future]
  ###   955$b is barcode
  ###   955$c is permanent location and library concatenated
  ###     into [library]$[location]
  ###   955$v is item description
  ###   Only include 955 fields outside the exclusion lists;
  ###   If there are no eligible items, return nil
  ### Remove all 9xx fields
  class GoogleRecordTransform
    attr_reader :original_record, :exclude_libraries, :exclude_locations, :changed_record

    def initialize(original_record:, exclude_libraries:, exclude_locations:)
      @original_record = original_record
      @exclude_locations = exclude_locations
      @exclude_libraries = exclude_libraries
      @changed_record = transform_record
    end

    private

    def transform_record
      return nil unless eligible_bib?

      new_record = clean_original_record
      new_record = attach_eligible_items(new_record)
      new_record['955'] ? new_record : nil
    end

    def eligible_bib?
      original_record.leader[6] == 'a' && original_record.leader[5] != 'd'
    end

    def clean_original_record
      new_record = MarcCleanup.duplicate_record(original_record)
      new_record.fields.delete_if { |f| f.tag[0] == '9' }
      new_record
    end

    def attach_eligible_items(record)
      eligible_f852.each do |holding_field|
        holding_id = holding_field['8']
        location = "#{holding_field['b']}$#{holding_field['c']}"
        associated_items(holding_id).each do |item_field|
          record.append(new_item_field(item_field: item_field,
                                       location: location))
        end
      end
      record
    end

    def eligible_f852
      original_record.fields('852').reject do |field|
        field['8'] =~ /^22/ &&
          (exclude_libraries.include?(field['b']) ||
            exclude_locations.include?("#{field['b']}$#{field['c']}"))
      end
    end

    def associated_items(holding_id)
      original_record.fields('876').select do |field|
        field['a'] =~ /^23/ && field['0'] == holding_id && field['p']
      end
    end

    def new_item_field(item_field:, location:)
      item_pid = item_field['a']
      barcode = item_field['p']
      description = item_field['3']
      new_field = MARC::DataField.new('955', ' ', ' ')
      new_field.append(MARC::Subfield.new('a', item_pid))
      new_field.append(MARC::Subfield.new('b', barcode))
      new_field.append(MARC::Subfield.new('c', location))
      new_field.append(MARC::Subfield.new('v', description)) if description
      new_field
    end
  end
end
