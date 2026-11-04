# frozen_string_literal: true

require '../lib/lsp-data'

client_id = ENV.fetch('PEOPLE_CLIENT_ID', nil)
client_secret = ENV.fetch('PEOPLE_CLIENT_SECRET', nil)
base_url = ENV.fetch('PEOPLE_BASE_URL', nil)
base_path = ENV.fetch('PEOPLE_BASE_PATH', nil)
return unless client_id && client_secret && base_url && base_path

output_dir = ENV.fetch('DATA_OUTPUT_DIR', nil)
oauth = OAuth.new(client_id: client_id,
                  client_secret: client_secret,
                  url: "#{base_url}/token")
oauth_response = oauth.response
if oauth_response[:status] == 200
  people_conn = OitPeople.new(base_url: "#{base_url}/#{base_path}", token: oauth_response[:token])
  people = people_conn.report(eligible_flag: 'E')[:people]
  File.open("#{output_dir}/pppl_users.tsv", 'w') do |output|
    output.puts("Last Name\tFirst Name\tUser Group\tPrimary Identifier")
    people.select { |person| person['VCURGROUP'] == 'PL' }.each do |person|
      output.write("#{person['PRF_OR_PRI_LAST_NAME']}\t")
      output.write("#{person['PRF_OR_PRI_FIRST_NAM']}\t")
      output.write("#{person['PVPATRONGROUP']}\t")
      output.puts(person['EMPLID'])
    end
  end
end
