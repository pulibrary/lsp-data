# frozen_string_literal: true

module LspData
  ### This class iterates through a given MARC file in a given directory to find
  ###   the records that should be sent to Google for a full export
  ###   that Google can ingest. It generates a MARC file with
  ###   the filtered records.
  class GoogleExport
    attr_reader :exclude_libraries, :exclude_locations,
                :input_file, :output_dir, :output_filename

    def initialize(exclude_libraries:, exclude_locations:, input_file:, output_dir:)
      @exclude_locations = exclude_locations
      @exclude_libraries = exclude_libraries
      @input_file = input_file
      @output_dir = output_dir
      @output_filename = "filtered_#{File.basename(input_file)}"
      create_file
    end

    private

    def create_file
      writer = MARC::XMLWriter.new("#{output_dir}/#{output_filename}")
      reader = MARC::XMLReader.new(input_file, parser: 'magic', ignore_namespace: true)
      reader.each do |record|
        update = GoogleRecordTransform.new(original_record: record,
                                           exclude_libraries: exclude_libraries,
                                           exclude_locations: exclude_locations)
        writer.write(update.changed_record) if update.changed_record
      end
      writer.close
    end
  end
end
