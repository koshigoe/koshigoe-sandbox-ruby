require 'sinatra'
require 'base64'
require 'json'

get '/redirect-from-https-to-http.csv' do
  redirect request.url.gsub(/\Ahttps/, 'http') if request.secure?
  return <<EOF
a,b,c
d,e,f
g,h,i
EOF
end

get '/image-base64' do
  JSON.generate(body: Base64.strict_encode64(File.read('public/image-base64.png')))
end

get '/redirect.json' do
  JSON.generate(location: 'http://koshigoe-sandbox-ruby.herokuapp.com/image-base64.png')
end

get '/brick_ftp_webhook' do
  request.query_string
end

get '/file.csv' do
  return ''
end
