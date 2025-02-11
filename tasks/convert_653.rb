# frozen_string_literal: true

### Acceptance criteria:
### - The 653 field of Activity books found in 9963637633506421 is replaced with the target 
###   field of `655 _7 $a Activity books. $2 lcgft
### - A mapping mechanism is developed in the script to translate lines of the spreadsheet into 
###   a hash of source values and target values

require_relative './../lib/lsp-data'
input_dir = ENV['DATA_INPUT_DIR']
output_dir = ENV['DATA_OUTPUT_DIR']
writer = MARC::XMLWriter.new("#{output_dir}/653_replaced.marcxml")
replacements = [
                 { source: "653  $a Activity books",
                   target: MARC::DataField.new('655',' ','7',['a','Activity books.'],['2','lcgft'])  
                 }
               ]

