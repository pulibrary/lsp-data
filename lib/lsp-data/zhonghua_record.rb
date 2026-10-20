# frozen_string_literal: true

### Codebase for parsing LSP data
module LspData
  ### Given a set of spreadsheet rows for the 'Zhonghua jing dian gu ji ku' database,
  ###   retrieve a matching record from OCLC and apply a set of transformations.
  ### Required elements:
  ###   1. From the Zhonghua CSV file:
  ###     a. Main Title
  ###     b. Series Title (may not have a series title)
  ###     c. Array of components, each of which is an object with the following elements:
  ###       - title [string]: The title of the component (optional)
  ###       - url [string]: The current URL of the component
  ###       - alternate_url_key [string]: The unique identifer found in a previous version of the URL.  
  ###         While these are no longer used on the platform itself, they may exist in WorldCat records  
  ###         and so are still useful as search keys.
  ###     d. ISBN
  ###   2. A Z3950connection object (already connected)
  class ZhonghuaRecord
    attr_reader :original_record, :main_title, :series_title, :components, :isbn, :conn

    def initialize(title_info:, conn:)
      @conn = conn
      @main_title = title_info[:main_title]
      @series_title = title_info[:series_title]
      @components = title_info[:components]
      @isbn = title_info[:isbn]
      @original_record ||= retrieve_record
    end

    ### Applies field additions/replacements/deletions using data in the row(s)
    def transformed_record
      return if original_record.nil?

      new_record = MarcCleanup.duplicate_record(original_record)
      delete_fields(record: new_record, tag_list: %w[001 003 035 019 029 505 856])
      replace_title_field(record: new_record, main_title: main_title)
      replace_series_fields(record: new_record, series_title: series_title)
      replace_urls(record: new_record, components: components)
      new_record
    end

    private

    ### Retrieves a WorldCat record using the search data in the first row
    def retrieve_record
      search_keys.reject { |key| key[:id].nil? }.each do |key|
        record = filtered_match(identifier: key[:id], identifier_type: key[:type])
        return record unless record.nil?
      end
      nil
    end

    ### Creates an array of search keys in the order to be attempted
    ### For single-title records, URLs are attempted first, then the ISBN
    ### For multi-record titles, the ISBN is attampted first, then the URLs
    def search_keys
      url_entries = components.map { |c| { id: c[:url], type: 'url' } } +
                    components.map { |c| { id: c[:alternate_url_key], type: 'url' } }
      isbn_entry = [{ id: isbn, type: 'isbn' }]
      components.one? ? (url_entries + isbn_entry) : (isbn_entry + url_entries)
    end

    ### Deletes all fields with the tags in the list, along with their associated 880s
    def delete_fields(record:, tag_list:)
      record.fields.delete_if do |field|
        tag_list.include?(field.tag) ||
          (field.tag == '880' && tag_list.include?(field['6'][0..2]))
      end
    end

    ### Deletes all existing instances of a field, and then adds a new instance
    def replace_field(record:, field:)
      delete_fields(record: record, tag_list: [field.tag])
      record.append(field)
    end

    ### Replaces the title (245a) field
    def replace_title_field(record:, main_title:)
      replace_field(record: record, field: MARC::DataField.new('245', '0', '0', MARC::Subfield.new('a', main_title)))
    end

    ### Replaces the series (490 and 830) fields, or deletes the existing fields if series_title is nil
    def replace_series_fields(record:, series_title:)
      if series_title.nil?
        delete_fields(record: record, tag_list: %w[490,830])
      else
        replace_field(record: record,
                      field: MARC::DataField.new('490', '1', ' ',
                                                 MARC::Subfield.new('a', series_title)))
        replace_field(record: record,
                      field: MARC::DataField.new('830', ' ', '0',
                                                 MARC::Subfield.new('a', series_title)))
      end
    end

    ### Removes any existing 856 and 956 fields, and adds the titles/urls from the component list
    ### URL is in 956$u, with optional title in 956$3
    def replace_urls(record:, components:)
      delete_fields(record: record, tag_list: %w[956])
      components.each do |c|
        url_field = MARC::DataField.new('956', '4', '1')
        url_field.append(MARC::Subfield.new('3', c[:title])) if c.key?(:title)
        url_field.append(MARC::Subfield.new('u', "https://#{c[:url]}"))
        record.append(url_field)
      end
    end

    ### Creates a field 917 containing the given identifier
    def tracking_field(identifier)
      MARC::DataField.new('917', ' ', ' ', MARC::Subfield.new('a', identifier))
    end

    ### Performs a Z39.50 search with the given identifier, filters results
    ###   Based on crieteria in the given row, returns the first result (if any)
    def filtered_match(identifier:, identifier_type:)
      match = OCLCRecordMatch.new(identifier: identifier, identifier_type: identifier_type, conn: conn)
                             .records.find do |record|
        !invalid_record?(record) && matched_title?(record)
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
def matched_title?(record)
  f880 = record.fields('880').find { |field| field['6'][0..2] == '245' }
  return false unless f880

  f880a_trad = ChineseConversion.new(f880['a']).converted.sub(/[\s\p{P}]+$/, '')
  # Title from spreadsheet should already be traditional, but this conversion will
  # still normalize any variant characters used.
  main_title_trad = ChineseConversion.new(main_title).converted
  /^#{main_title_trad}/.match?(f880a_trad)
end
