require './app'
require './bot'

map "/" do
  run(Sinatra::Application)
end

map "/bot" do
  run(Facebook::Messenger::Server)
end