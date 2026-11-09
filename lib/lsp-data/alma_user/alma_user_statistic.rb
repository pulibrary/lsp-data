# frozen_string_literal: true

module LspData
  ### A class that represents a statistical category for Alma as a hash that will be parsed in AlmaUser
  ### See https://developers.exlibrisgroup.com/alma/apis/docs/xsd/rest_user.xsd#user_statistic
  ### Fields to process:
  ###   statistic_category [element with a `value` attribute; stored in a code table in Alma]
  ###   segment_type [will always be set to 'Internal']
  class AlmaUserStatistic
    attr_reader :statistic_category

    def initialize(statistic_category)
      @statistic_category = statistic_category
    end

    def to_h
      { 'statistic_category' => { 'value' => statistic_category },
        'segment_type' => 'Internal' }
    end
  end
end
