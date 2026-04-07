# frozen_string_literal: true

### Codebase for parsing LSP data
module LspData
  ### Given a set of spreadsheet rows for the 'Zhonghua jing dian gu ji ku' database,
  ###   retrieve a matching record from OCLC and apply a set of transformations.
  ### Required elements:
  ###   1. A set of rows from the Zhonghua csv file (loaded into a 2D array with the 'CSV' library)
  ###   2. A Z3950connection object (already connected)
  class ZhonghuaRecord
    attr_reader :original_record, :main_title, :series_title, :url, :alternate_url, :isbn, :conn

    def initialize(main_title:, series_title:, url:, alternate_url:, isbn:, conn:)
      @conn = conn
      @main_title = main_title
      @series_title = series_title
      @url = url
      @alternate_url = alternate_url
      @isbn = isbn
      @original_record ||= retrieve_record
    end

    ### Applies field additions/replacements/deletions using data in the row(s)
    def transformed_record
      new_record = duplicate_record(original_record)
      delete_fields(record: new_record, tag_list: %w[001 003 035 019 029 505 856])
      replace_field(record: new_record, tag: '245', ind1: '0', ind2: '0', subfield: 'a', content: title)
      replace_field(record: new_record, tag: '490', ind1: '0', ind2: ' ', subfield: 'a', content: series_title)
      replace_field(record: new_record, tag: '830', ind1: ' ', ind2: '0', subfield: 'a', content: series_title)
      replace_field(record: new_record, tag: '956', ind1: '4', ind2: '1', subfield: 'u', content: url)
    end

    ### Retrieves a WorldCat record using the search data in the first row
    def retrieve_record
      search_keys.each do |key|
        record = filtered_match(identifier: key[:id], identifier_type: key[:type])
        return record unless record.nil?
      end
    end

    ### Creates an array of search keys in the order to be attempted
    def search_keys
      [{ id: url, type: 'url' }, { id: alternate_url, type: 'url' }]
      + [{ id: isbn, type: 'isbn' }] if isbn
    end

    ### Deletes all fields with the tags in the list, along with their associated 880s
    def delete_fields(record:, tag_list:)
      record.fields.delete_if do |field|
        tag_list.include?(field.tag) ||
          (field.tag == '880' && tag_list.include?(field['6'][0..2]))
      end
    end

    ### Deletes all existing instances of a field, and then adds a new instance
    def replace_field(record:, tag:, ind1:, ind2:, subfield:, content:)
      delete_fields(record: record, tag_list: [tag])
      record.append(MARC::DataField.new(tag, ind1, ind2, MARC::Subfield.new(subfield, content)))
    end

    ### Creates a field 917 containing the given identifier
    def tracking_field(identifier:)
      MARC::DataField.new('917', ' ', ' ', MARC::Subfield.new('a', identifier))
    end

    ### Performs a Z39.50 search with the given identifier, filters results
    ###   Based on crieteria in the given row, returns the first result (if any)
    def filtered_match(identifier:, identifier_type:)
      match = OCLCRecordMatch.new(identifier: identifier, identifier_type: identifier_type, conn: conn)
                             .records.find do |record|
        !invalid_record?(record) &&
          matched_title?(record)
      end
      return unless match

      match.append(tracking_field(identifier))
      match
    end
  end

  ### Indicates if a record is of suffient quality to be used
  def invalid_record?(record)
    %w[3 u z].include?(record.leader[17]) ||
      record['040']['b'] != 'eng' ||
      record['245']['a'] !~ /[A-Za-z]/ ||
      record['880'].nil? ||
      record['948']['h'] =~ / 0 OTHER HOLDINGS/ ||
      insufficient_subjects?(record)
  end

  ### Indicates if a record lacks enough classification data
  def insufficient_subjects?(record)
    record['050'].nil? || record.fields('600'..'655').empty?
  end
end

### Indicates if the title in the row matches the title in the record
def matched_title?(record:)
  f880 = record.fields('880').find { |field| field['6'][0..2] == '245' }
  return false unless f880

  /^#{main_title}/.match?(f880['a'])
end
