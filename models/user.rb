require 'httparty'
require 'chain'
require 'bip_mnemonic'
require 'money-tree'
require 'blockcypher-ruby'
require 'facebook/messenger'

class User < ActiveRecord::Base
  validates :nickname, uniqueness: true
  
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
    
    create_btc_wallet
  end
  
  def get_btc_address
    # get user mnemonic
    e = BipMnemonic.to_entropy(mnemonic: self.mnemonic)
    
    # open a bitcoin testnet HD wallet based on the mnemonic
    master = MoneyTree::Master.new(seed_hex: e, network: :bitcoin_testnet)
    
    # navigate to the first node and get addr
    node = master.node_for_path "m/0"
    addr = node.to_address(network: :bitcoin_testnet)
    
    # used to sign micro tx
    # wif = node.private_key.to_wif(network: :bitcoin_testnet)
    
    # return addr 'm/0'
    self.update!(:btc_addr => addr)
    addr
  end
    
  def btc_balance(currency: nil)
    b = BlockCypher::Api.new({api_token: ENV['BLOCKCYPHER_TOKEN'], network: ENV['BLOCKCYPHER_NETWORK'], version: BlockCypher::V1})
    s = b.address_final_balance(self.btc_addr)
    
    return s if currency.nil?
    
    HTTParty.get("https://blockchain.info/frombtc?currency=#{currency}&value=#{s}").parsed_response
  end
  
  def create_btc_wallet
    # generate 128 bits of entropy and convert to a readable mnemonic
    m = BipMnemonic.to_mnemonic(bits: 128)
    e = BipMnemonic.to_entropy(mnemonic: m)
    
    # open a bitcoin testnet HD wallet based on the mnemonic
    master = MoneyTree::Master.new(seed_hex: e, network: :bitcoin_testnet)
    xpub = master.to_bip32(:public, network: :bitcoin_testnet)
    
    b = BlockCypher::Api.new({api_token: ENV['BLOCKCYPHER_TOKEN'], network: ENV['BLOCKCYPHER_NETWORK'], version: BlockCypher::V1})
    # add xpub and create wallet on blockcypher
    # b.wallet_hd_create(self.nickname, xpub)
    # b.wallet_hd_derive_addr(self.nickname)
        
    # update mnemonic for that user
    self.update!(:mnemonic => m)
    
    # get bitcoin addr 'm/0'
    addr = get_btc_address
    
    # setup a webhook for that addr
    url = "#{ENV['URL_HOST']}/callbacks/new-tx?token=#{ENV['VERIFY_TOKEN']}"
    b.event_webhook_subscribe(url, "unconfirmed-tx", address: addr)
    
    # return mnemonic
    m
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
  
  def transfer_woolong(sender, receiver, amount, chain)
    signer = Chain::HSMSigner.new
    
    # asset xpub
    signer.add_key(ENV['CHAIN_EIN_XPUB'], chain.mock_hsm.signer_conn)
    
    # ein xpub
    signer.add_key(ENV['CHAIN_EIN_XPUB'], chain.mock_hsm.signer_conn)

    # user xpub
    signer.add_key(self.xpub, chain.mock_hsm.signer_conn)

    spending_tx = chain.transactions.build do |b|
      b.spend_from_account account_alias: sender, asset_alias: 'woolong', amount: amount
      b.control_with_account account_alias: receiver, asset_alias: 'woolong', amount: amount
    end
    
    signed_spending_tx = signer.sign(spending_tx)
    chain.transactions.submit(signed_spending_tx)
  end
  
  def send_message(msg)
    Bot.deliver({
      recipient: {
        id: self.scoped_id
      },
      message: {
        text: msg
      }
    }, access_token: ENV['ACCESS_TOKEN'])
  end
  
end