# frozen_string_literal: true

module LspData
  ### Transform a FiggyDigitalObject into XML that Alma can ingest
  ###   Mandatory elements:
  ###     1. Identifier (the unique ID of the manifest; will be in a 999$a)
  ###     2. Unique part of the ARK (will be in a 999$c);
  ###       this will be transformed into the full ARK in Alma
  ###     2. Repository code based on visibility (figgy-private, figgy-open, etc.);
  ###       this will be an attribute separate from the XML
  ###     3. IIIF Manifest; will be in a 999$d
  ###     4. MMS ID; will be in 001
  ###     5. Title (will always be `digital inventory`); will be in 245$a
  ###     6. Collection; will be in 987$t;
  ###       for now, there will be one collection per object derived from the visibility
  ###       (e.g., Figgy open objects, Figgy private, Figgy princeton objects)
  ###     7. Label: will be in a 999$b
  class AlmaDigitalObject
    attr_reader :mms_id, :figgy_object, :repository_code, :iiif_manifest

    def initialize(mms_id:, figgy_object:)
      @mms_id = mms_id
      @figgy_object = figgy_object
      @repository_code = "figgy-#{figgy_object.visibility.gsub(/\s/, '_')}"
    end

    def record
      return @record if defined?(@record)

      record_from_figgy_data
    end

    def marc_record
      return @marc_record if defined?(@marc_record)

      rec = MARC::Record.new
      rec.leader = '#####ckm#a22#####2i#4500'
      rec.append(MARC::ControlField.new('001', mms_id))
      rec.append(MARC::DataField.new('245', '0', '0', MARC::Subfield.new('a', 'digital inventory')))
      rec.append(collection_field)
      rec.append(inventory_field)
      @marc_record = rec
    end

    private

    ### Alma cannot process files if the XML version is declared
    ### See https://knowledge.exlibrisgroup.com/@api/deki/files/46942/OAI_MARC_SAMPLE.xml?revision=1
    ###   for the schema details
    def record_from_figgy_data
      Nokogiri::XML::Builder.new do |xml|
        xml.record do
          xml.header do
            xml.setSpec 'Digital'
          end
          xml << "<metadata>#{marc_record.to_xml}</metadata>"
        end
      end.to_xml.gsub("<?xml version=\"1.0\"?>\n", '')
    end

    def unique_ark_portion(ark)
      ark.gsub(%r{^https?://arks.princeton.edu/ark:/88435/(.*)$}, '\1')
    end

    def inventory_field
      MARC::DataField.new('999', ' ', ' ',
                          MARC::Subfield.new('a', figgy_object.manifest_identifier),
                          MARC::Subfield.new('b', figgy_object.label),
                          MARC::Subfield.new('c', unique_ark_portion(figgy_object.ark)),
                          MARC::Subfield.new('d', figgy_object.manifest_url))
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
