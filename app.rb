require 'sinatra'
require 'sinatra/activerecord'
require './config/environments'
require './models/user'

set :logging, true

get '/' do
  html = <<-HTML
<html>
<body>

See ya space Cowboy! 

<br/>
<br/>

<img src="http://vignette1.wikia.nocookie.net/cowboybebop/images/c/cd/6_Ein1.png" alt="Ein" />

</body>
</html>
HTML

  html
end