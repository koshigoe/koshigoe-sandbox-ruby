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

post '/dump-http-post-request' do
  p request.env

  request.body.rewind
  p request.body.read

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

get '/rss' do
  n = (params[:n] || 10).to_i
  pub_date = Time.now.getgm.strftime('%a, %d %b %Y %H:%M:%S GMT')

  content_type 'application/rss+xml'
  header = <<~XML
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:media="http://search.yahoo.com/mrss/" xmlns:snf="http://www.smartnews.be/snf">
      <channel>
        <title>スマートタイムス</title>
        <link>http://times.smartnews.co.jp/</link>
        <description>スマートなニュースをすべての人へ</description>
        <pubDate>#{pub_date}</pubDate>
        <language>ja</language>
        <copyright>(c) SmartNews, Inc.</copyright>
        <ttl>1</ttl>
        <snf:logo><url>http://times.smartnews.co.jp/snlogo.png</url></snf:logo>
  XML
  items = n.times.map do |i|
    <<~XML
        <item>
            <title>#{i}: 渋谷区桜丘エリアの再開発計画が決定</title>
            <link>http://times.smartnews.co.jp/2014/06/16/sakuragaoka?#{i}</link>
            <guid>http://times.smartnews.co.jp/2014/06/16/sakuragaoka?#{i}</guid>
            <description><![CDATA[
          渋谷駅桜丘口地区再開発準備組合と東急不動産株式会社は、2014年6月16日、渋谷区の市街地再開発等の都市開発計画が東京都により決定されたと発表した。
            ]]></description>
            <pubDate>#{pub_date}</pubDate>
            <content:encoded><![CDATA[
          <p>渋谷駅桜丘口地区再開発準備組合と東急不動産株式会社は、2014年6月16日、渋谷区の市街地再開発等の都市開発計画が東京都により決定されたと発表した。</p>
          <p>この都市計画は、2013年12月19日より東京都知事に対して提案されていたもので、渋谷駅中心地区の都市基盤整備を完成させる重要なプロジェクトとなっている。</p>
          <p>今後、周辺再開発と連携した縦動線アーバン・コア、歩行者デッキ、ネットワークの整備を行うほか、街区再編と併せた都市計画道路の整備および地下車路ネットワーク等の整備により、利便性・安全性の向上を図っていくとのこと。</p>
          <figure>
              <img src="img.png">
              <figcaption>完成イメージ</figcaption>
          </figure>
            ]]></content:encoded>
            <category>iphone,technology</category>
            <dc:creator>須磨戸 太郎</dc:creator>
            <dc:language>ja</dc:language>
            <media:thumbnail url="http://times.smartnews.co.jp/2014/06/16/sakuragaoka/img.png" />
          <snf:advertisement>
            <snf:sponsoredLink link="http://times.smartnews.com/sponsored/article1.html" thumbnail="http://times.smartnews.com/sponsored/image1.jpg" title="桜丘に新スイーツ店が誕生！" advertiser="桜丘スイーツ"/>
            <snf:sponsoredLink link="http://times.smartnews.com/sponsored/article2.html" thumbnail="http://times.smartnews.com/sponsored/image2.jpg" title="sponsored link 2" advertiser="Example Company"/>
          </snf:advertisement>
          <snf:analytics><![CDATA[
            <script>
          (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
          (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
          m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
          })(window,document,'script','//www.google-analytics.com/analytics.js','ga');

          ga('create', 'UA-xxx-2', 'examplecom');
          ga('require', 'displayfeatures');
          ga('set', 'referrer', 'http://www.smartnews.com/');
          ga('send', 'pageview', '/260984/upsee/');
            </script>
            ]]>
          </snf:analytics>
        </item>
    XML
  end
  footer = <<~XML
    </channel>
    </rss>
  XML

  header + items.join + footer
end
