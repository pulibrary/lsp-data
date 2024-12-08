# frozen_string_literal: true

require 'marc'
require 'nokogiri'
require 'marc_cleanup'
require_relative 'lsp-data/connection'
require_relative 'lsp-data/marc_data'
require_relative 'lsp-data/match_key_overlap'
require_relative 'lsp-data/standard_nums'
require_relative 'lsp-data/constants'
require_relative 'lsp-data/parsed_call_num'
include LspData
