require 'sinatra'
require 'base64'
require 'json'

helpers do
  def protect!
    return if authorized?

    response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
    throw(:halt, [401, "Not authorized\n"])
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    username = '+@user'
    password = '+@pass'
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [username, password]
  end
end

get '/basic-auth' do
  protect!

  <<~EOF
    a,b,c
    1,2,3
  EOF
end

get '/dump-http-request' do
  p request.env
  return ''
end

get '/dump-http-request.png' do
  p request.env
  content_type 'image/png'
  File.read('public/test.png')
end

get '/' do
  [200, {}, 'OK.']
end

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

get '/redirect' do
  redirect params[:url]
end

get '/500' do
  [500, {}, 'ERROR']
end

get '/http-error' do
  status = params[:code].to_i
  status = 500 unless (500...600).cover?(status)
  [status, {}, 'ERROR']
end

HTTP_STATUS = [500, 500, 200]
get '/500-500-200' do
  status = HTTP_STATUS.first
  HTTP_STATUS.rotate!
  [status, {}, status.to_s]
end

COUNTER = Hash.new(0)
SENARIO = {
  'a' => [
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込設定
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込1回目
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 取込2回目
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 構成変更開始
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 構成変更完了
  ],
  'b' => [
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込設定
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込1回目
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 取込2回目
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 構成変更開始
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 構成変更失敗
  ],
  'c' => [
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込設定
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込1回目
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 取込2回目
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 構成変更開始
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/403', # 構成変更失敗
  ],
  'd' => [
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込設定
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 取込設定2回目(構成変更モーダル表示)
    'http://koshigoe-sandbox-ruby.herokuapp.com/sleep?t=60', # 構成変更待ち
  ],
  'e' => [
    'http://reference.dfplus.io/sample/sample_masterdata.csv', # 取込設定
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 取込1回目(構成変更検知)
    'http://s3-ap-northeast-1.amazonaws.com/df-monkey-preview/testdata/sample_masterdata.conflict.csv', # 構成変更モーダル表示
    'http://koshigoe-sandbox-ruby.herokuapp.com/sleep?t=60', # 構成変更待ち
  ],
}

get '/cycle' do
  urls = SENARIO[params[:s] || 'a']
  id = "#{params[:s]}.#{params[:k]}"
  index = COUNTER[id] % urls.size

  if params[:st]
    list = Array.new(urls.size, '  ').zip(urls)
    list[index][0] = '* '
    [200, { 'Content-Type' => 'text/plain' }, list.map(&:join).join("\n")]
  else
    COUNTER[id] += 1
    redirect urls[index]
  end
end

get '/sleep' do
  t = params[:t].to_f

  sleep t if t > 0

  [200, {}, "sleep #{t} sec."]
end

get '/blank-columns.csv' do
  [200, {}, Array.new(params[:n].to_i).join(',')]
end

get '/cycle-success-error' do
  error = params[:e].to_i
  counter_id = "cycle-success-error-#{error}"
  index = COUNTER[counter_id] % 2
  COUNTER[counter_id] += 1

  if index == 0
    [200, {}, "a,b,c\n1,2,3"]
  else
    [error, {}, '']
  end
end

post '/aws-transfer-auth' do
  [
    200,
    {
      'Content-Type' => 'application/json',
    },
    {
      'Role' => 'arn:aws:iam::166616333867:role/koshigoe-transfer-sandbox-RoleForTransferUser-10KZZBYHI2ZYS',
      # 'Policy' => '',
      'HomeDirectoryType' => 'LOGICAL',
      'HomeDirectoryDetails' => [
        'Entry' => '/',
        'Target' => '/ff-sandbox-koshigoe/test',
      ].to_json,
    }.to_json
  ]
end
