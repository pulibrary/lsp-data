# frozen_string_literal: true

module LspData
  ### A class that represents a phone number for Alma as a hash that will be parsed in AlmaUser
  ### See https://developers.exlibrisgroup.com/alma/apis/docs/xsd/rest_user.xsd#phone
  ### Fields to process:
  ###   phone_number
  ###   phone_type [element with a `value` attribute; stored in a code table in Alma; will only allow one type]
  ###   preferred [true or false]
  ###   segment_type [will always be set to 'Internal']
  class AlmaPhone
    attr_reader :phone_number, :phone_type, :preferred

    def initialize(phone_number:, phone_type:, preferred:)
      @phone_number = phone_number
      @phone_type = phone_type
      @preferred = preferred
    end

    def to_h
      { 'phone_number' => phone_number,
        'phone_type' => [{ 'value' => phone_type }],
        'preferred' => preferred,
        'segment_type' => 'Internal' }
    end
  end
end
