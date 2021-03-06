require 'httparty'
require 'httmultiparty'
require 'facebook/messenger'
require 'chain'
require 'uri'
require 'foursquare2'
require './models/user'

include Facebook::Messenger
chain = Chain::Client.new(:access_token => ENV['CHAIN_ACCESS_TOKEN'], :url => ENV['CHAIN_URL'])
help_cmds = "hi, balance, play, hello, sell, address, meta or what humans like?"

Bot.on :message do |message|
  puts "on :message '#{message.inspect}' from #{message.sender}"
  
  message.type
  
  u = User.find_by_scoped_id(message.sender["id"])

  # user doesn't exist
  if u.nil?
    message.reply(
      text: 'Hi. I see you are new here. I will remember about you. Tell me your nickname.'
    )
    User.setup_user(message.sender["id"])
    next
  end
  
  # user needs to setup a nickname
  if u.chat_context == "TELL_NICKNAME"
    begin
      u.update!(:nickname => message.text.split.last, :chat_context => "READY_TO_PLAY")
    rescue ActiveRecord::RecordInvalid => e
      message.reply(
        text: "Oh no! #{e.message.gsub("Validation failed: ", "")}. Say a different nickname"
      )
      next
    end
    
    message.reply(
      text: "Well done @#{message.text.split.last}. Use your nickname to play with your friends ...",
    )
    message.type
    message.reply(
      attachment: {
        type: 'image',
        payload: {
          url: 'https://media.giphy.com/media/vncgdgPWLwGRi/giphy.gif'
        }
      }
    )
    message.type
    u.create_wallet(chain)
    
    message.reply(
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: 'Im giving you 1000 woolongs to play',
          buttons: [
            { type: 'postback', title: 'Check balance', payload: 'CHECK_BALANCE' },
            { type: 'postback', title: 'Lets play', payload: 'LETS_PLAY' }
          ]
        }
      }
    )
    u.transfer_woolong("ein", u.nickname, 1000, chain)
    next
  end
  
  if message.attachments
    if message.attachments.first['type'] == 'location'
      coords = message.attachments.first['payload']['coordinates']
      lat = coords['lat']
      long = coords['long']
      
      client = Foursquare2::Client.new(:client_id => ENV['FOURSQUARE_ID'], :client_secret => ENV['FOURSQUARE_SECRET'], :api_version => '20170301')
      m = client.search_venues(:ll => "#{lat},#{long}", :query => '')
      m.venues.first.contact
      
      message.reply(
        text: "I think you are at #{m.venues.first.name}",
      )
      
      next
    end
  end
  
  if u.chat_context == "TAG_IMAGE_TXT"
    u.update!(:chat_context => "TAG_IMAGE_IMG", :chat_context_buffer => message.text)
    message.reply(
      text: "Now send me a picture of the product you wanna sell",
    )
    next
  end
  
  if u.chat_context == "TAG_IMAGE_IMG" and message.attachments
    price = u.chat_context_buffer.split(" ").last
    product = u.chat_context_buffer.gsub(price, "").strip
    addr = u.btc_addr
    btc = BitcoinUtil.currency_to_btc(price)
    
    t = "bitcoin:#{addr}?amount=#{btc}&product=#{URI.escape(product)}"
    
    # define random filename to write on ephemeral system
    fn = "./tmp/#{rand(36**16).to_s(36)}.jpg"

    # save attachment image
    File.open(fn, "wb") do |f|
      f.write HTTParty.get(message.attachments.first["payload"]["url"]).parsed_response
      f.close
    end
    
    # upload to API to tagimage with InfinitePay QR Code
    response = HTTMultiParty.post("https://infinite-qrcode.herokuapp.com/tagimage", :query => {:text=> t, :file => File.new(fn)}).parsed_response
    
    puts ">>> #{response}"
        
    message.reply(
      attachment: {
        type: 'image',
        payload: {
          url: response
        }
      }
    )
    
    u.update!(:chat_context => "READY_TO_PLAY", :chat_context_buffer => "")
    next
  end
  
  # user sent an image
  unless message.attachments.nil?
    puts ">>> received an image ..."
    
    # define random filename to write on ephemeral system
    fn = "./tmp/#{rand(36**16).to_s(36)}.jpg"

    # save attachment image
    File.open(fn, "wb") do |f|
      f.write HTTParty.get(message.attachments.first["payload"]["url"]).parsed_response
      f.close
    end

    # upload to API to decode InfinitePay QR Code
    response = HTTMultiParty.post('https://zxing.org/w/decode', :query => {:file => File.new(fn)}).parsed_response
        
    data = /<pre>(.*?)<\/pre>/.match(response)
    if data.nil?
      # replay with not found message
      message.reply(
        text: "Beautiful picture <3. Please send me picture with cool QR codes ..."
      )
    else
      # check if is a bitcoin address with amount
      btc = BitcoinUtil.parse_bitcoin_uri(data[1])
            
      unless btc.nil?
        addr = btc[:addr]
        
        # validate bitcoin uri parameters
        if btc[:parameters].nil?
          message.reply(
            text: "Bitcoin address should contain amount and product ..."
          )
          next
        end
        
        amount = btc[:parameters]["amount"][0]
        product = btc[:parameters]["product"][0]
        
        if addr and amount and product
          satoshis = (amount.to_f * 1e8).to_i
          
          message.reply(
            attachment: {
              type: 'template',
              payload: {
                template_type: 'button',
                text: "Would you like to buy #{product} for $ #{BitcoinUtil.satoshi_to_currency(satoshis)}? Your current balance is $ #{u.btc_balance(currency: 'USD')}",
                buttons: [
                  { type: 'postback', title: 'Yes', payload: "BTCPAYMENTCONFIRM_#{addr}_#{satoshis}" },
                  { type: 'postback', title: 'No', payload: "BTCPAYMENTCANCELLED" }
                ]
              }
            }
          )
        end
      else
        # replay message with QR Code decoded
        message.reply(
          text: "#{data[1]}"
        )
      end
    end

    next
  end
  
  case message.text    

  when /hi/i
    message.reply(
      text: "Hi. Welcome back @#{u.nickname}. You can say #{help_cmds}"
    )
    
  when /sell/i
    u.update!(:chat_context => "TAG_IMAGE_TXT")
    message.reply(
      text: "Please, describe the product you wanna sell in the format (product price in USD) ex: iphone 7 10"
    )
 
  when /balance/i
    message.reply(
      text: "You have #{u.balance(chain)} woolongs and $ #{u.btc_balance(currency: 'USD')} in bitcoins on your wallet"
    )
  
  when /address/i
    addr = u.btc_addr
    message.reply(
      text: "Your bitcoin address is: #{addr}"
    )
    message.type
    message.reply(
      attachment: {
        type: 'image',
        payload: {
          url: HTTParty.get("https://infinite-qrcode.herokuapp.com/encode?s3=true&t=bitcoin:#{addr}").parsed_response
        }
      }
    )
    
  when /meta/i
    message.reply(
      attachment: {
        type: 'image',
        payload: {
          url: 'https://cdn-images-1.medium.com/max/1000/1*rGiRHME_Roqsgz2CUg5yrg.png'
        }
      }
    )
    
  when /play/i
    play_coin(message)
    
  when /hello/i    
    message.reply(
      text: 'Hello, human!',
      quick_replies: [
        {
          content_type: 'text',
          title: 'Hello, ein!',
          payload: 'HELLO_BOT'
        }
      ]
    )
    
  when /humans like/i
    message.reply(
      text: 'I found something humans seem to like:'
    )

    message.reply(
      attachment: {
        type: 'image',
        payload: {
          url: 'https://i.imgur.com/iMKrDQc.gif'
        }
      }
    )

    message.reply(
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: 'Did human like it?',
          buttons: [
            { type: 'postback', title: 'Yes', payload: 'HUMAN_LIKED' },
            { type: 'postback', title: 'No', payload: 'HUMAN_DISLIKED' }
          ]
        }
      }
    )  
  else
      message.reply(
        text: "You can say #{help_cmds}"
      )    
  end
  
end

Bot.on :postback do |postback|
  puts "on :postback '#{postback.inspect}'"
    
  u = User.find_by_scoped_id(postback.sender["id"])
  text = '🍄'
  
  case postback.payload
  when 'HUMAN_LIKED'
    postback.type
    text = 'That makes ein happy!'
    postback.reply(
      text: text
    )
  when 'HUMAN_DISLIKED'
    postback.type
    text = 'Oh.'
    postback.reply(
      text: text
    )
  when 'CHECK_BALANCE'
    postback.type
    text = "You have #{u.balance(chain)} woolongs in your wallet"
    postback.reply(
      text: text
    )
  when 'LETS_PLAY'
    postback.type
    text = 'Alright ...'
    postback.reply(
      text: text
    )
  end
  
  if (postback.payload == "LETS_PLAY" || postback.payload == 'TRY_AGAIN_PLAY')
    postback.type
    play_coin(postback)
  end
  
  if (postback.payload == 'LETS_PLAY_COIN_BET100')
    toss_coin(postback, 100, u, chain)
  end
  
  if (postback.payload == 'LETS_PLAY_COIN_BET200')
    toss_coin(postback, 200, u, chain)
  end
  
  if (postback.payload == 'LETS_PLAY_COIN_BET1000')
    toss_coin(postback, 1000, u, chain)
  end
  
  if (postback.payload == 'BTCPAYMENTCANCELLED')
    postback.reply(
      text: "Maybe you don't really need this product, right ..." 
    )
  end
  
  if (postback.payload[0..16] == 'BTCPAYMENTCONFIRM')
    addr = postback.payload.split('_')[1]
    satoshis = postback.payload.split('_')[2] 
    
    # call bitcoin payment ...
    h = u.transfer_btc(addr, satoshis)
    
    if h[:hash].nil?
      postback.reply(
        text: "Payment failed: #{h[:message]}" 
      )
    else
      postback.reply(
        text: "Payment completed!  https://live.blockcypher.com/btc-testnet/tx/#{h[:hash]}" 
      )
    end
    
  end
  
end

Bot.on :delivery do |delivery|
  puts "Delivered message(s) #{delivery.ids}"
end

def play_coin(ctx)
  ctx.reply(
    attachment: {
      type: 'template',
      payload: {
        template_type: 'button',
        text: "I'll flip a coin. You are head! How much woolongs are you gonna bet?",
        buttons: [
          { type: 'postback', title: '100', payload: 'LETS_PLAY_COIN_BET100' },
          { type: 'postback', title: '200', payload: 'LETS_PLAY_COIN_BET200' },
          { type: 'postback', title: '1000', payload: 'LETS_PLAY_COIN_BET1000' }
        ]
      }
    }
  )
end

def toss_coin(ctx, amount, user, chain) 
  if (user.balance(chain) < amount)
    ctx.reply(
      text: "Unfortunately you don't have enough woolongs to play. I can give you more woolongs if you behave like a good human."
    )
    return
  end
  
  ctx.reply(
    attachment: {
      type: 'image',
      payload: {
        url: 'https://media.giphy.com/media/10bv4HhibS9nZC/giphy.gif'
      }
    }
  )
  
  flip = rand(0..1)
  ctx.type
  
  if (flip == 1)    
    user.transfer_woolong("ein", user.nickname, amount, chain)
    
    ctx.reply(
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: "Uow! You won #{amount} woolongs! You have #{user.balance(chain)} woolongs in your wallet.",
          buttons: [
            { type: 'postback', title: 'Try again', payload: 'TRY_AGAIN_PLAY' }
          ]
        }
      }
    )    
  end
  
  if (flip == 0)
    user.transfer_woolong(user.nickname, "ein", amount, chain)
        
    ctx.reply(
      attachment: {
        type: 'template',
        payload: {
          template_type: 'button',
          text: "Yeah!!! I won #{amount} woolongs! You lose and still have #{user.balance(chain)} woolongs in your wallet.",
          buttons: [
            { type: 'postback', title: 'Try again!!!', payload: 'TRY_AGAIN_PLAY' }
          ]
        }
      }
    )
  end
  
end