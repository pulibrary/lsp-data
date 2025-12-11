# frozen_string_literal: true

module LspData
  ISBN13PREFIX = '978'
  METADATA_API_ENDPOINT = 'https://metadata.api.oclc.org/worldcat'
  SEARCH_API_ENDPOINT = 'https://americas.discovery.api.oclc.org/worldcat/search/v2'
  OCLC_OAUTH_ENDPOINT = 'https://oauth.oclc.org/token'
  OCLC_Z3950_DATABASE_NAME = 'OLUCWorldCat'
  OCLC_Z3950_ENDPOINT = 'zcat.oclc.org'
  OCLC_Z3950_USER = ENV.fetch('OCLC_Z3950_USER', nil)
  OCLC_Z3950_PASSWORD = ENV.fetch('OCLC_Z3950_PASSWORD', nil)
end
