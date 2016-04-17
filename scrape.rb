require 'mechanize'

class Kumamoto
  def initialize
    agent = Mechanize.new
    agent.open_timeout = 5
    agent.read_timeout = 5
    @site = agent.get('http://www.city.kumamoto.jp/default.aspx?site=1')
  rescue
  end

  def success?
    !@site.nil?
  end

  def info_area
    @site
      .search('[@id="kinkyuInfo"]')
      .search('[@class="kinkyuR"]')
  end

  def info_hash
    return nil unless @site
    array = []
    info_area.each do |area|
      tmp_hash = {}

      tmp_hash[:title] = area.search('p')[0].text.strip
      tmp_hash[:message] = area.search('p')[1].text.strip

      array.push tmp_hash
    end
    return array
  end
end

class Kisyo
  def initialize
    agent = Mechanize.new
    agent.open_timeout = 5
    agent.read_timeout = 5
    @site = agent.get('http://www.jma.go.jp/jp/quake/quake_singen_index.html')
  rescue
  end

  def success?
    !@site.nil?
  end

  def info_area
    @site
      .search('[@id="info"]')
      .search('table')
      .search('tr')
  end

  def record(record, num)
    record.search('td').length
    record.search('td')[num]
  end

  def info_hash
    return nil unless @site
    array = []
    info_area.each do |area|
      next if area.text.include?('情報発表日時')
      tmp_hash = {}

      tmp_hash[:info_time] = record(area, 0).text.strip
      tmp_hash[:detect_time] = record(area, 1).text.strip
      tmp_hash[:place] = record(area, 2).text.strip
      tmp_hash[:mag] = record(area, 3).text.strip

      array.push tmp_hash
    end
    return array
  end
end

class Suido
  def initialize
    agent = Mechanize.new
    agent.open_timeout = 5
    agent.read_timeout = 5
    @site = agent.get('http://www.kumamoto-waterworks.jp/?page_id=2880')
  rescue
  end

  def success?
    !@site.nil?
  end

  def e_links
    @site
      .search('[@id="e_middle"]')
      .search('a')
      .map{|link| link.attribute('href').text}
  end

  def info_area(page)
    page
      .search('[@id="contents"]')
  end

  def record(record, num)
    record.search('td')[num]
  end

  def info_hash
    return nil unless @site
    array = []
    e_links.each do |link|

      p link

      begin
        agent = Mechanize.new
        agent.read_timeout = 60
        page = agent.get(link)
      rescue Timeout::Error
        retry

      end

      info = info_area(page)

      tmp_hash = {}

      tmp_hash[:title] = info.search('h3').text.strip
      tmp_hash[:message] = info.search('p').text

      array.push tmp_hash
    end
    return array
  end
end

class Html

  def initialize
    @earth_quake_info = Kisyo.new.info_hash
    @kumamoto_info    = Kumamoto.new.info_hash
    @suido            = Suido.new.info_hash
    @file             = original_file
  end

  def original_file
    File.open('./original.html'){|file| file.read}
  end

  def export_info
    html = File.open('index.html', 'r')
    doc = Nokogiri::HTML.parse(html)

    ENV['TZ'] = 'Asia/Tokyo'

    if @earth_quake_info
      @file.gsub!('{{kisyo}}', earth_quake)
      @file.gsub!('{{earthquake_last_updated_at}}', Time.now.strftime('%Y年%m月%d日 %H時%M分').to_s)
    else
      @file.gsub!('{{kisyo}}', doc.search('[@class="area earthquake"]')[0].to_s)
    end


    if @kumamoto_info
      @file.gsub!('{{kumamotoshi}}', kumamotoshi)
      @file.gsub!('{{cityinfo_last_updated_at}}', Time.now.strftime('%Y年%m月%d日 %H時%M分').to_s)
    else
      @file.gsub!('{{kumamotoshi}}', doc.search('[@class="area cityinfo"]')[0].to_s)
    end


    if @suido
      @file.gsub!('{{suido}}', suido)
      @file.gsub!('{{suido_last_updated_at}}', Time.now.strftime('%Y年%m月%d日 %H時%M分').to_s)
    else
      @file.gsub!('{{suido}}', doc.search('[@class="area waterworks"]')[0].to_s)
    end
  end

  def write_html
    export_info
    File.open('./index.html', 'w') do |file|
      file << @file
    end
  end

  def earth_quake
    html = '<div class="area earthquake">
              <div class="areaTitle">地震情報（震源に関する情報）<span class="u-warn" style="font-size:13px;"> 最終更新日時:{{earthquake_last_updated_at}}</span></div>
              <div class="area-info">
                <div class="area-info__message">
                  <div class="title">地震情報（震源に関する情報）</div>'
    h = ''
    @earth_quake_info.each do |i|
      h += "<div class='message'>"
      h += "#{i[:info_time]}#{i[:detect_time]}#{i[:place]}#{i[:mag]}"
      h += '</div>'
    end
    html += h
    html += '</div></div></div>'

    return html
  end

  def kumamotoshi
    html = '<div class="area cityinfo">
              <div class="areaTitle">熊本市<span class="u-warn" style="font-size:13px;"> 最終更新日時:{{cityinfo_last_updated_at}}</span></div>
                <div class="area-info">'
    h = ''
    @kumamoto_info.each do |i|
      h += "<div class='area-info__message'>"
      h += "<div class='day'>#{Time.now.strftime('%m月%d日').to_s}</div>"
      h += "<div class='title'>#{i[:title]}</div>"
      h += "<div class='message'>#{i[:message]}</div>"
      h += '</div>'
    end
    html += h
    html += '</div></div>'

    return html
  end

  def suido
    html = '<div class="area waterworks">
              <div class="areaTitle">上下水道局<span class="u-warn" style="font-size:13px;"> 最終更新日時:{{suido_last_updated_at}}</span></div>
                <div><a href="http://www.city.kumamoto.jp/kinkyu/pub/default.aspx?c_id=3" target="_blank">地震に伴う緊急情報一覧について</a></div>
                <div class="area-info">'
    h = ''
    @suido.each do |i|
      h += "<div class='area-info__message'>"
      h += "<div class='title'>#{i[:title]}</div>"
      h += "<div class='message'>#{i[:message]}</div>"
      h += '</div>'
    end
    html += h
    html += '</div></div>'

    return html
  end
end

p Html.new.write_html

require 'aws-sdk'
s3 = Aws::S3::Client.new(
  access_key_id: 'AKIAIQWKX2WYP6FHN2RA',
  secret_access_key: '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',
  region: 'ap-northeast-1'
)

s3.put_object(
  bucket: 'kumamoto-jishin.info',
  body: File.open('index.html'),
  key: 'index.html'
)
