# frozen_string_literal: true

module LspData
  ### Transform a hash derived from the Figgy report into an object with the following
  ###   mandatory features:
  ###    1. Visibility (princeton, open, reading room, private, on campus) (taken from the visibility label)
  ###    2. MMS ID (key of the hash)
  ###    3. IIIF Manifest URL
  ### If the visibility is open, retrieve the metadata from the manifest and add
  ###   the following features:
  ###     1. Label
  ###     2. ARK
  ###     3. Thumbnail URL
  class FiggyDigitalObject
    attr_reader :mms_id, :visibility, :manifest_url, :conn, :manifest_identifier

    def initialize(manifest_info:, mms_id:, conn:)
      @visibility = manifest_info['visibility']['label']
      @manifest_url = manifest_info['iiif_manifest_url']
      @manifest_identifier ||= identifier_from_manifest_url
      @mms_id = mms_id
      @conn = conn
    end

    def manifest_metadata
      return @manifest_metadata if defined?(@manifest_metadata)

      all_metadata = manifest
      return @manifest_metadata = nil if all_metadata.nil?

      body = all_metadata[:body]
      @manifest_metadata = all_metadata[:status] == 200 ? metadata_from_manifest(body) : nil
    end

    private

    def metadata_from_manifest(body)
      collection_data = body['metadata'].find { |object| object['label'] == 'Member Of Collections' }.to_h
      {
        ark: body['rendering']['@id'],
        thumbnail: body['thumbnail']['@id'],
        label: body['label'],
        collections: collection_data['value']
      }
    end

    def identifier_from_manifest_url
      manifest_url.gsub(%r{^.*scanned_resources/([^/]+)/.*$}, '\1')
    end

    def manifest
      return unless visibility == 'open'

      response = api_call
      parse_api_response(response)
    end

    def api_call
      conn.get do |req|
        req.url "#{manifest_identifier}/manifest"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
      end
    end
  end
end
