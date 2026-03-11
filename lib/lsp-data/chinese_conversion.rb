# frozen_string_literal: true

### Codebase for parsing LSP data
module LspData
  ROOT_DIR = File.join(File.dirname(__FILE__), '../..')
  SIMP_TRAD_TABLE = YAML.load_file("#{ROOT_DIR}/yaml/chi_simp_trad_table.yml")['simp_to_trad']

  ### This class is used to convert Chinese
  class ChineseConversion
    # Convert a Chinese text string from Simplified to Traditional characters
    def convert_string_to_trad(chi_simp_str:)
      chi_trad_str = ''
      chi_simp_str.each_char do |char|
        chi_trad_str += SIMP_TRAD_TABLE.key?(char) ? SIMP_TRAD_TABLE[char] : char
      end
      chi_trad_str
    end

    # Converts an entire MARC record object from Simplified to Traditional characters
    def convert_rec_to_trad(chi_simp_rec:)
      chi_simp_mrc = chi_simp_rec.to_marc
      chi_trad_mrc = convert_string_to_trad(chi_simp_str: chi_simp_mrc)
      MARC::Record.new_from_marc(chi_trad_mrc)
    end
  end
end
