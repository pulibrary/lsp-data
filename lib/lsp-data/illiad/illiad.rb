# frozen_string_literal: true

module LspData
  ### This class retrieves information from ILLiad and transforms it into an array of objects.
  ### An ILLiad connection is created upon instantiating the class
  class ILLiad
    attr_reader :conn

    def initialize
      @conn = TinyTds::Client.new({ username: ILLIAD_USER, password: ILLIAD_PASS, host: ILLIAD_HOST,
                                    database: ILLIAD_DB })
    end
  end
end
