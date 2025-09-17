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
  ###     4. Collections
  class FiggyDigitalObject
    attr_reader :mms_id, :visibility, :manifest_url, :conn,
                :manifest_identifier, :manifest_unique_portion

    def initialize(manifest_info:, mms_id:, conn:)
      @visibility = manifest_info['visibility']['label']
      @manifest_url = manifest_info['iiif_manifest_url']
      @manifest_unique_portion = manifest_url.gsub(%r{^.*concern/([^/]+/[^/]+)/.*$}, '\1')
      @manifest_identifier ||= identifier_from_manifest_url
      @mms_id = mms_id
      @conn = conn
      @manifest_metadata = manifest_metadata
    end

    def manifest_metadata
      return @manifest_metadata if defined?(@manifest_metadata)

      all_metadata = manifest
      return @manifest_metadata = nil if all_metadata.nil?

      body = all_metadata[:body]
      @manifest_metadata = metadata_from_manifest(body)
    end

    private

    def metadata_from_manifest(body)
      {
        ark: ark(body),
        thumbnail: thumbnail(body),
        label: label(body),
        collections: collections(body)
      }
    end

    def identifier_from_manifest_url
      manifest_unique_portion.gsub(%r{^[^/]+/([^/]+)$}, '\1')
    end

    def label(body)
      if body['label'].instance_of?(String)
        body['label']
      else
        body['label']['eng'].first
      end
    end

    def thumbnail(body)
      if body['thumbnail'].instance_of?(Array)
        body['thumbnail'].find { |object| object['format'] == 'image/jpeg' }['id']
      else
        body['thumbnail']['@id']
      end
    end

    def ark(body)
      if body['rendering'].instance_of?(Array)
        body['rendering'].find { |object| object['format'] == 'text/html' }['id']
      else
        body['rendering']['@id']
      end
    end

    def collections(body)
      english_label = body['metadata'].find { |object| object['label']['eng']&.include?('Member Of Collections') }
      if english_label
        english_label['value']['eng']
      else
        body['metadata'].find { |object| object['label'] == 'Member Of Collections' }&.[]('value')
      end
    end

    ### Figgy does not return the body in JSON format if the status is not 200
    def manifest
      return unless visibility == 'open'

      response = api_call
      return unless response.status == 200

      parse_api_response(response)
    end

    def api_call
      conn.get do |req|
        req.url "#{manifest_unique_portion}/manifest"
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
      end
    end
  end
end
