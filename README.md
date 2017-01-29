ein-bot
=========

![alt text](http://vignette1.wikia.nocookie.net/cowboybebop/images/c/cd/6_Ein1.png "Logo")

## Description

I'm a super intelligent dog

## Setup
You should setup the Facebook messenger webhooks, pointing to this sinatra app.


```shell
export ACCESS_TOKEN=EAACC4tt1Qk8BAAZCFIpMHZBoLtyggxlTGGfXaHZAGembpo4P83bjbnMjEIl1rDZBVFgRqdmCg1A7GSI5C8Ja6Tzr5aJ08fR03VKt4TeuSQT0ZCrlnLe6XS97wn7A7OFArxP8RzQ1lE1BNLQs8Tmk6hSWAa3hUbZCgRJ7eEqP9heAZDZD
export APP_SECRET=037a55ce01006afb090542116d7228ec
export VERIFY_TOKEN=cc16df065beabe9c8371183d34cd6c12

export CHAIN_ACCESS_TOKEN=einbot:03657a6f071b0b797b84bfd71fb2e8ee83f997a98f6295e91cec59a486e5b742
export CHAIN_URL=https://ein-chain.herokuapp.com
export CHAIN_EIN_XPUB=6dccf25759b8b90ccb2f0245a7f57392e6912c52fd15f7a91921543b7f978e67f591d2c33edc47eeecd57f7d427adb8419b22947dfab0df3d2994c8c79c83e5b

bundle install
bundle exec rackup
```

## License

```
The MIT License (MIT)
Copyright (c) 2017 Luis Silva

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```