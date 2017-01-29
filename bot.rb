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
        text: "Hi. Welcome back @#{u.nickname}"
      )
    end
    
  when /balance/i
    unless u.nil?
      message.reply(
        text: "You have #{u.balance(chain)} woolongs in your wallet"
      )
    end
    
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
    
  when /something humans like/i
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
    else
      message.reply(
        text: '🍄'
      )    
    end
  end
  
end

Bot.on :postback do |postback|
  puts "on :postback '#{postback.inspect}'"
  
  postback.type
  
  u = User.find_by_scoped_id(postback.sender["id"])
  
  case postback.payload
  when 'HUMAN_LIKED'
    text = 'That makes ein happy!'
  when 'HUMAN_DISLIKED'
    text = 'Oh.'
  when 'CHECK_BALANCE'
    text = "You have #{u.balance(chain)} woolongs in your wallet"
  when 'LETS_PLAY'
    text = 'Say the name your friend, game and how much your are betting. ex: @ein dice 100 woolongs'
  end
  postback.reply(
    text: text
  )
end

Bot.on :delivery do |delivery|
  puts "Delivered message(s) #{delivery.ids}"
end