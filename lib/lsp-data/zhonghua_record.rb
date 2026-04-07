# frozen_string_literal: true

### Codebase for parsing LSP data
module LspData
  ### Given a set of spreadsheet rows for the 'Zhonghua jing dian gu ji ku' database,
  ###   retrieve a matching record from OCLC and apply a set of transformations.
  ### Required elements:
  ###   1. A set of rows from the Zhonghua csv file (loaded into a 2D array with the 'CSV' library)
  ###   2. A Z3950connection object (already connected)
  class ZhonghuaRecord
    attr_reader :rec, :conn

    def initialize(rows:, conn:)
      @conn = conn
      @rec = retrieve_record(rows: rows)
      apply_transformations(rows: rows)
    end

    ### Applies field additions/replacements/deletions using data in the row(s)
    def apply_transformations(rows:)
      delete_fields_parallels(tag_list: %w[001 003 035 019 029 505 856])
      add_replace_field(tag: '245', ind1: '0', ind2: '0', sfcode: 'a', content: rows[0]['题名'])
      add_replace_field(tag: '490', ind1: '0', ind2: ' ', sfcode: 'a', content: rows[0]['其他题名信息'])
      add_replace_field(tag: '830', ind1: ' ', ind2: '0', sfcode: 'a', content: rows[0]['其他题名信息'])
      add_replace_field(tag: '956', ind1: '4', ind2: '1', sfcode: 'a', content: rows[0]['URL'])
    end

    ### Retrieves a WorldCat record using the search data in the first row
    def retrieve_record(rows:)
      record = nil
      get_search_keys(rows: rows).each do |k|
        record = filtered_match(identifier: k[:id], identifier_type: k[:type], row: rows[0])
        break unless rec.nil?
      end
      record
    end

    ### Creates an array of search keys in the order to be attempted
    def get_search_keys(rows:)
      return [] unless rows.one?

      search_keys = [{ id: rows[0]['URL'].gsub(%r{^https?://(.*)$}, '\1'), type: 'url' }]
      old_url = rows[0]['唯一标识符']
      search_keys << { id: old_url, type: 'url' } if old_url =~ /^ZHB/
      isbn = isbn_normalize(rows[0]['标准编号'].gsub(/^ISBN (.*)$/, '\1'))
      search_keys << { id: isbn, type: 'isbn' } unless isbn.nil?
    end

    ### Deletes all fields with the tags in the list, along with their associated 880s
    def delete_fields_parallels(tag_list:)
      tag_list.each do |tag|
        @rec.fields.delete_if do |field|
          field.tag == tag ||
            (field.tag == '880' && field['6'][0..2] == tag)
        end
      end
    end

    ### Deletes all existing instances of a field, and then adds a new instance
    def add_replace_field(tag:, ind1:, ind2:, sfcode:, content:)
      new_field = MARC::DataField.new(tag, ind1, ind2)
      new_field.append(MARC::Subfield.new(sfcode, content))
      delete_fields_parallels(tag_list: [tag])
      @rec.append(new_field)
    end

    ### Creates a field 917 containing the given identifier
    def tracking_field(identifier)
      field = MARC::DataField.new('917', ' ', ' ')
      field.append(MARC::Subfield.new('a', identifier))
      field
    end

    ### Performs a Z39.50 search with the given identifier, filters results
    ###   Based on crieteria in the given row, returns the first result (if any)
    def filtered_match(identifier:, identifier_type:, row:)
      matches = OCLCRecordMatch.new(identifier: identifier, identifier_type: identifier_type, conn: conn)
                               .records.reject do |record|
        invalid_record?(record) &&
          !matched_title?(row: row, record: record) &&
          !series_requirement?(row: row, record: record)
      end
      return nil if matches.none?

      matches[0].append(tracking_field(identifier))
      matches[0]
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
def matched_title?(row:, record:)
  title_to_match = match_title(title_type: title_type(row), row: row)
  f880 = record.fields('880').find { |field| field['6'][0..2] == '245' }
  f880.nil? || /^#{title_to_match}/.match?(f880['a'])
end

### Indicates the kind of title (used to determine the MARC and spreadsheet
###   fields to use for matching)
def title_type(row)
  if row['其他题名信息']
    'collection'
  else
    'single'
  end
end

### Selects the appriate spreadsheet field for title matching based on title type
def match_title(title_type:, row:)
  if title_type == 'single'
    row['题名']
  else
    row['其他题名信息'].gsub(/^\*(.*)$/, '\1')
  end
end

### Indicates if both the record and row contain a series title
def series_requirement?(row:, record:)
  if row['丛编']
    record.fields('490').size.positive?
  else
    true
  end
end
