require 'httparty'

class BitcoinUtil
  
  def self.satoshi_to_currency(amount, currency: 'USD')
    HTTParty.get("https://blockchain.info/frombtc?currency=#{currency}&value=#{amount}").parsed_response
  end
  
end