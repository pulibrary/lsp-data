# frozen_string_literal: true

module LspData
  ### Return all matched records by a standard number identifier
  ###   and have a separate method to return records deemed acceptable
  ###   for copy cataloging
  ### Must provide a Z3950Connection object for OCLC
  ### identifier_type is either `isbn` or 'oclc'
  class OCLCRecordMatch
    attr_reader :identifier, :identifier_type, :conn

    def initialize(identifier:, identifier_type:, conn:)
      @identifier = identifier
      @identifier_type = identifier_type
      @conn = conn
    end

    def records
      search_index = case identifier_type
                     when 'isbn'
                       7
                     when 'oclc'
                       12
                     end
      return unless search_index

      result = conn.search_by_id(index: search_index, identifier: identifier)
      result.reject(&:nil?)
    end

    def filtered_records(title)
      all_records = records
      all_records.select { |record| acceptable_record?(record, title) }
    end

    private

    def acceptable_leader?(record)
      [' ', '1', '4', 'I', 'M', 'L'].include?(record.leader[17]) &&
        record.leader[6..7] == 'am'
    end

    def belle_lettres?(record)
      %w[1 d f j m p].include?(record['008'].value[33])
    end

    def acceptable_subject?(record)
      record.fields('600'..'655').any? { |field| field.indicator2 == '0' }
    end

    def pcc050?(record)
      record.fields('042').any? { |f| f['a'] == 'pcc' } && record['050']
    end

    def call_num050?(record)
      record.fields('050').any? { |f| f['a'] =~ /\d/ }
    end

    def dlc040?(record)
      record['040'] =~ /DLC/
    end

    def electronic_reproduction?(record)
      record.fields('006').any? { |field| field.value[0] == 'm' } ||
        record.fields('007').any? { |field| field.value[0] == 'c' } ||
        record['245']['h'] ||
        record['533']
    end

    def normalize_string(string)
      strip_punctuation(string).unicode_normalize(:nfd)
                               .gsub(/\p{InCombiningDiacriticalMarks}/, '')
                               .downcase
    end

    def strip_punctuation(string)
      string.gsub('%22', '')
            .gsub(/^\s*[aA]\s+/, '')
            .gsub(/^\s*[aA]n\s+/, '')
            .gsub(/^\s*[Tt]he\s+/, '')
            .gsub(/['{}]/, '')
            .gsub('&', 'and')
            .gsub(/[\u0020-\u0025\u0028-\u002f]/, '')
            .gsub(/[\u003a-\u0040\u005b-\u0060]/, '')
            .gsub(/[\u007c\u007e\u00a9]/, '')
    end

    def process_title(title)
      normalized = normalize_string(title)
      "#{normalized[5..9]}#{normalized[14..18]}"
    end

    def title_match?(record, title)
      process_title(title)
      process_title(title) == process_title(record['245']['a'])
    end

    def acceptable_record?(record, title)
      acceptable_leader?(record) &&
        acceptable_f040b?(record) &&
        (belle_lettres?(record) || acceptable_subject?(record)) &&
        call_num050?(record) &&
        title_match?(record, title) &&
        electronic_reproduction?(record) == false
    end

    def acceptable_f040b?(record)
      record['040']['b'].nil? || record['040']['b'] == 'eng'
    end
  end
end
