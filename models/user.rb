require 'httparty'
require 'chain'

class User < ActiveRecord::Base
  def self.get_sender_profile(scoped_id)
    request = HTTParty.get(
      "https://graph.facebook.com/v2.6/#{scoped_id}",
      query: {
        access_token: ENV['ACCESS_TOKEN'],
        fields: 'first_name,last_name,gender,profile_pic'
      }
    )

    request.parsed_response
  end

  def self.setup_user(scoped_id)
    fb_user = self.get_sender_profile(scoped_id)
    name = "#{fb_user["first_name"]} #{fb_user["last_name"]}"
    self.create(:name => name, :picture => fb_user["profile_pic"], :scoped_id => scoped_id, 
                :chat_context => "TELL_NICKNAME")  
  end
  
  def create_wallet(chain)
    key = chain.mock_hsm.keys.create(:alias => self.nickname)
    self.update!(:xpub => key.xpub)
    
    chain.accounts.create(
      alias: self.nickname,
      root_xpubs: [self.xpub],
      quorum: 1,
      tags: {
        scoped_id: self.scoped_id,
        user_id: self.id,
        name: self.name
      }
    )
  end
  
  def balance(chain)
    balances = chain.balances.query(
      filter: 'account_alias=$1 AND asset_alias=$2',
      filter_params: [self.nickname, 'woolong'],
    )
    if balances.first.nil? 
      0 
    else
      balances.first.amount
    end
  end

end