# frozen_string_literal: true

module LspData
  ### A class that represents a user note for Alma as a hash that will be parsed in AlmaUser
  ### See https://developers.exlibrisgroup.com/alma/apis/docs/xsd/rest_user.xsd#user_note
  ### Fields to process:
  ###   note_type [element with a `value` attribute; stored in a code table in Alma; will only allow one type]
  ###   note_text
  ###   segment_type [will always be 'Internal']
  class AlmaUserNote
    attr_reader :note_type, :note_text

    def initialize(note_type:, note_text:)
      @note_type = note_type
      @note_text = note_text
    end

    def to_h
      { 'note_type' => { 'value' => note_type }, 'note_text' => note_text, 'segment_type' => 'Internal' }
    end
  end
end
