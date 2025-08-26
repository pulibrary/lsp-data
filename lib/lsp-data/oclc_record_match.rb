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
      all_records&.select { |record| acceptable_record?(record, title) }
    end

    private

    def acceptable_leader?(record)
      [' ', '1', '7', 'I', 'M', 'L'].include?(record.leader[17]) &&
        record.leader[6..7] == 'am'
    end

    ### If the work is fiction, drama, or poetry, no LCSH required, but LCGFT is
    def belle_lettres?(record)
      %w[1 d f j m p].include?(record['008'].value[33]) &&
        record.fields('655').any? { |field| field.indicator2 == '7' && field['2'] == 'lcgft' }
    end

    def acceptable_subject?(record)
      record.fields('600'..'655').any? { |field| field.indicator2 == '0' }
    end

    def pcc050?(record)
      record.fields('042').any? { |f| f['a'] == 'pcc' } && record['050']
    end

    def call_num050?(record)
      record.fields('050').any? { |f| f['a'] =~ /\d/ && f['b'] }
    end

    def dlc040?(record)
      record['040'] =~ /DLC/
    end

    def lc?(record)
      record.fields('050').any? { |f| f.indicator1 == '0' || f.indicator2 == '0' } &&
        dlc040?(record) &&
        record.fields('010').any? { |f| f['a'] }
    end

    def electronic_reproduction_fixed_fields?(record)
      record.fields('006').any? { |field| field.value[0] == 'm' } ||
        record.fields('007').any? { |field| field.value[0] == 'c' }
    end

    def electronic_reproduction?(record)
      electronic_reproduction_fixed_fields?(record) ||
        record.fields('245').any? { |field| field['h'] } ||
        record.fields('533').size.positive?
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
      "#{normalized[4..8]}#{normalized[14..18]}"
    end

    def title_match?(record, title)
      process_title(title) == process_title(record['245']['a'])
    end

    def acceptable_non_lc?(record)
      acceptable_leader?(record) &&
        acceptable_f040b?(record) &&
        (belle_lettres?(record) || acceptable_subject?(record)) &&
        call_num050?(record) &&
        (electronic_reproduction?(record) == false)
    end

    def acceptable_record?(record, title)
      (lc?(record) || pcc050?(record) || acceptable_non_lc?(record)) &&
        title_match?(record, title)
    end

    def acceptable_f040b?(record)
      record['040'].nil? || record['040']['b'].nil? || record['040']['b'] == 'eng'
    end
  end
end
