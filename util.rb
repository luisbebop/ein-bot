require 'httparty'
require 'cgi'

class BitcoinUtil
  
  def self.satoshi_to_currency(amount, currency: 'USD')
    HTTParty.get("https://blockchain.info/frombtc?currency=#{currency}&value=#{amount}").parsed_response
  end
  
  def self.currency_to_btc(amount, currency: 'USD')
    HTTParty.get("https://blockchain.info/tobtc?currency=#{currency}&value=#{amount}").parsed_response
  end
  
  def self.parse_bitcoin_uri(s)
    return nil if s[0..7] != 'bitcoin:'
    addr = s.split('?')[0].split(':')[1]
    params = s.split('?')[1].nil? ? nil : CGI::parse(s.split('?')[1])
    {addr: addr, parameters: params}
  end
  
end