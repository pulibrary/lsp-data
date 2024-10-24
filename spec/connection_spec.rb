require_relative './../lib/lsp-data'

RSpec.describe 'api_conn' do
  describe 'alma api connection' do
    let(:url) { 'https://api-na.exlibrisgroup.com' }
    let(:conn) { LspData.api_conn(url) }
    it 'creates an object of the class Faraday::Connection' do
      expect(conn.class).to eq Faraday::Connection
    end
  end
end
