# frozen_string_literal: true

module LspData
  ### Transform a hash derived from the Figgy report into an object with the following
  ###   mandatory features:
  ###    1. Visibility (princeton, open, reading room, private, on campus) (taken from the visibility label)
  ###    2. MMS ID (key of the hash)
  ###    3. IIIF Manifest URL
  ###    4. Manifest identifier (unique portion of Manifest URL)
  ###    5. Label
  ###    6. ARK
  class FiggyDigitalObject
    attr_reader :mms_id, :visibility, :manifest_url, :conn,
                :manifest_identifier, :manifest_unique_portion, :ark, :label

    def initialize(manifest_info:, mms_id:, conn:)
      @visibility = manifest_info['visibility']['label']
      @manifest_url = manifest_info['iiif_manifest_url']
      @manifest_unique_portion = manifest_url.gsub(%r{^.*concern/([^/]+/[^/]+)/.*$}, '\1')
      @manifest_identifier ||= identifier_from_manifest_url
      @ark = manifest_info['ark']
      @mms_id = mms_id
      @conn = conn
      @label = label_from_manifest(manifest_info['label'])
    end

    private

    def identifier_from_manifest_url
      manifest_unique_portion.gsub(%r{^[^/]+/([^/]+)$}, '\1')
    end

    def label_from_manifest(label_info)
      if label_info.instance_of?(String)
        label_info
      else
        label_info['@value']
      end
    end
  end
end
