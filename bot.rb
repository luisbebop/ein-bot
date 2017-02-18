require 'facebook/messenger'
require 'chain'
require './models/user'

include Facebook::Messenger
chain = Chain::Client.new(:access_token => ENV['CHAIN_ACCESS_TOKEN'], :url => ENV['CHAIN_URL'])

Bot.on :message do |message|
  puts "on :message '#{message.inspect}' from #{message.sender}"
  
  message.type
  
  u = User.find_by_scoped_id(message.sender["id"])
  
  case message.text    
  when /hi/i
    if u.nil?
      message.reply(
        text: 'Hi. I see you are new here. I will remember about you. Tell me your nickname.'
      )
      User.setup_user(message.sender["id"])
    else
      message.reply(
        text: "Hi. Welcome back @#{u.nickname}. You can say balance, play, hello, or what humans like?"
      )
    end
    
  when /balance/i
    unless u.nil?
      message.reply(
        text: "You have #{u.balance(chain)} woolongs in your wallet"
      )
    end
    
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
    if u.chat_context == "TELL_NICKNAME"
      u.update!(:nickname => message.text, :chat_context => "READY_TO_PLAY")
      message.reply(
        text: "Well done @#{message.text}. Use your nickname to play with your friends ...",
      )
      message.type
      message.reply(
        attachment: {
          type: 'image',
          payload: {
            url: 'http://i.giphy.com/aZzXDWIjefE5y.gif'
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
      
    else
      message.reply(
        text: '🍄'
      )    
    end
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
        url: 'http://i.giphy.com/10bv4HhibS9nZC.gif'
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