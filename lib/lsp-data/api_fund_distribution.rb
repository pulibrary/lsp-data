# frozen_string_literal: true

module LspData
  ### This class makes a model of a fund distribution
  ###   returned from Alma via API.
  class ApiFundDistribution
    attr_reader :fund_distribution

    def initialize(fund_distribution:)
      @fund_distribution = fund_distribution
    end

    def percent
      @percent ||= BigDecimal(fund_distribution['percent'].to_s)
    end

    def amount
      @amount ||= BigDecimal(fund_distribution['amount'].to_s)
    end

    def fund_code
      @fund_code ||= begin
        info = fund_distribution['fund_code']
        { name: info['desc'], code: info['value'] } if info
      end
    end
  end
end
