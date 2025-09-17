# frozen_string_literal: true

module LspData
  ### Transform a FiggyDigitalObject into XML that Alma can ingest
  ###   Mandatory elements:
  ###     1. Identifier (for open items, the unique ID of the ARK; for other items,
  ###       the unique ID of the manifest); will be in a 999$a
  ###     2. Repository code based on visibility (figgy-private, figgy-open, etc.);
  ###       this will be an attribute separate from the XML
  ###     3. IIIF Manifest; will be in a 999$d
  ###     4. MMS ID; will be in 001
  ###     5. Title (will always be `digital inventory`); will be in 245$a
  ###     6. Collection; will be in 987$t;
  ###       for now, there will be one collection per object derived from the visibility
  ###       (e.g., Figgy open objects, Figgy private, Figgy princeton objects)
  ###   Additional elements for open items:
  ###     1. Label; will be in a 999$b
  ###     2. Thumbnail URL unique identifier (with square formatting instead of
  ###       the full resolution); will be in a 999$c
  class AlmaDigitalObject
    attr_reader :mms_id, :figgy_object, :repository_code, :iiif_manifest

    def initialize(mms_id:, figgy_object:)
      @mms_id = mms_id
      @figgy_object = figgy_object
      @repository_code = "figgy-#{figgy_object.visibility.gsub(/\s/, '_')}"
      @primary_identifier = primary_identifier
    end

    def record
      return @record if defined?(@record)

      record_from_figgy_data
    end

    def primary_identifier
      return @primary_identifier if defined?(@primary_identifier)

      if figgy_object.visibility == 'open' && figgy_object.manifest_metadata
        figgy_object.manifest_metadata[:ark].gsub(%r{^https?://arks\.princeton\.edu/ark:/88435/(.*)$}, '\1')
      else
        figgy_object.manifest_identifier
      end
    end

    def marc_record
      return @marc_record if defined?(@marc_record)

      rec = MARC::Record.new
      rec.leader = '#####ckm#a22#####2i#4500'
      rec.append(MARC::ControlField.new('001', mms_id))
      rec.append(title_field)
      rec.append(collection_field)
      rec.append(inventory_field)
      @marc_record = rec
    end

    private

    def record_from_figgy_data
      Nokogiri::XML::Builder.new do |xml|
        xml.record do
          xml.header do
            xml.setSpec 'Digital'
          end
          xml << "<metadata>#{marc_record.to_xml}<\/metadata>"
        end
      end.to_xml
    end

    def title_field
      field = MARC::DataField.new('245', '0', '0')
      field.append(MARC::Subfield.new('a', 'digital inventory'))
      field
    end

    def append_optional_inventory(field)
      field.append(MARC::Subfield.new('b', figgy_object.manifest_metadata[:label]))
      field.append(MARC::Subfield.new('c', thumbnail_identifier))
    end

    def inventory_field
      field = MARC::DataField.new('999', ' ', ' ',
                                  MARC::Subfield.new('a', primary_identifier),
                                  MARC::Subfield.new('d', figgy_object.manifest_url))
      append_optional_inventory(field) if figgy_object.visibility == 'open' && figgy_object.manifest_metadata
      field
    end

    def thumbnail_identifier
      raw_identifier = figgy_object.manifest_metadata[:thumbnail].gsub(
        %r{^https://iiif-cloud.princeton.edu/iiif/(.*intermediate_?file).*$}, '\1'
      )
      "#{raw_identifier}/square/225,/0/default.jpg"
    end

    def collection_name
      "Figgy #{figgy_object.visibility} objects"
    end

    def collection_field
      field = MARC::DataField.new('987', ' ', ' ')
      field.append(MARC::Subfield.new('t', collection_name))
      field
    end
  end
end
