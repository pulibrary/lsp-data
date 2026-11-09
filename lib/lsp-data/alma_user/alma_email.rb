# frozen_string_literal: true

module LspData
  ### A class that represents an email for Alma as a hash that will be parsed in AlmaUser
  ### See https://developers.exlibrisgroup.com/alma/apis/docs/xsd/rest_user.xsd#email
  ### Fields to process:
  ###   email_address
  ###   email_type [element with a `value` attribute; stored in a code table in Alma; will only allow one type]
  ###   preferred [true or false]
  ###   segment_type [will always be set to 'Internal']
  class AlmaEmail
    attr_reader :email_address, :email_type, :preferred

    def initialize(email_address:, email_type:, preferred:)
      @email_address = email_address
      @email_type = email_type
      @preferred = preferred
    end

    def to_h
      { 'email_address' => email_address,
        'email_type' => [{ 'value' => email_type }],
        'preferred' => preferred,
        'segment_type' => 'Internal' }
    end
  end
end
