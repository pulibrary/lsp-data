# frozen_string_literal: true

module LspData
  ### A class that represents an address for Alma as a hash that will be parsed in AlmaUser
  ### See https://developers.exlibrisgroup.com/alma/apis/docs/xsd/rest_user.xsd#address
  ### Fields to process:
  ###   lines [1-5 lines for a street address] [String]
  ###   postcode_city_state_country [hash of elements named `postcode`, `city`, `state`, and 'country']
  ###   start_date [String; yyyy-mm-ddZ]
  ###   address_type [element with a `value` attribute; stored in a code table in Alma; will onnly allow one type]
  ###   preferred [true or false]
  ###   segment_type [will always be set to 'Internal']
  class AlmaAddress
    attr_reader :lines, :postcode_city_state_country, :start_date, :address_type, :preferred

    def initialize(lines:, postcode_city_state_country:, start_date:, address_type:, preferred:)
      @lines = lines
      @postcode_city_state_country = postcode_city_state_country
      @start_date = start_date
      @address_type = address_type
      @preferred = preferred
    end

    def to_h
      { 'city' => postcode_city_state_country[:city],
        'state_province' => postcode_city_state_country[:state],
        'country' => { 'value' => postcode_city_state_country[:country] },
        'postal_code' => postcode_city_state_country[:postcode],
        'start_date' => start_date,
        'address_type' => [{ 'value' => address_type }],
        'preferred' => preferred,
        'segment_type' => 'Internal' }.merge(process_lines(lines))
    end

    private

    def process_lines(lines)
      hash = {}
      lines[0..4].each_with_index do |line, index|
        hash["line#{index + 1}"] = line
      end
      hash
    end
  end
end
