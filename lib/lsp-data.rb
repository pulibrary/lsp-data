# frozen_string_literal: true

require 'marc'
require 'nokogiri'
require 'marc_cleanup'
require 'marc_match_key'
require 'zoom'
require 'tiny_tds'
Dir.glob("#{File.dirname(__FILE__)}/lsp-data/*.rb").each do |file|
  require file
end
Dir.glob("#{File.dirname(__FILE__)}/lsp-data/illiad/*.rb").each do |file|
  require file
end
include LspData
