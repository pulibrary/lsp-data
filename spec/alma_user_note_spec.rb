# frozen_string_literal: true

require_relative '../lib/lsp-data'
require 'spec_helper'

RSpec.describe LspData::AlmaUserNote do
  subject(:alma_user_note) do
    described_class.new(note_type: note_type,
                        note_text: note_text)
  end

  context 'general note' do
    let(:note_text) { 'this is a note' }
    let(:note_type) { 'POPUP' }
    it 'returns a valid note segment' do
      expect(alma_user_note.to_h['note_text']).to eq 'this is a note'
      expect(alma_user_note.to_h['note_type']['value']).to eq 'POPUP'
    end
  end
end
