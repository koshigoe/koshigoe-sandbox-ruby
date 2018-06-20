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
}

get '/cycle' do
  urls = SENARIO[params[:s] || 'a']
  id = "#{params[:s]}.#{params[:k]}"
  index = COUNTER[id] % urls.size

  if params[:st]
    list = Array.new(urls.size, '  ').zip(urls)
    list[index][0] = '* '
    [200, {}, list.map(&:join).join("\n")]
  else
    COUNTER[id] += 1
    redirect urls[index]
  end
end
