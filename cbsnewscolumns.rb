require 'open-uri'
require 'rubygems'
require 'nokogiri'
require 'md5'
require 'erb'
require 'cgi'
require 'cp_convert'
require 'date'

include CP1252

def h(txt)
  CGI.escapeHTML txt
end

$debug = ENV['DEBUG'] || 0

def get_rows(doc)
  all = doc/"ul.newsListing li"
end

def get_date(element)
    dt = element.at("p.datestamp").text
end

def get_link(element)
  h(element.at("a.storyTitle")['href'])
end

def get_headline(element)
    hlt=element.at("a.storyTitle").text
end

def get_description(element)
    img = element.at("img.storyImg").to_s
    txt=img + element.at("p.storyDek").text
    txt=kill_gremlins(txt)
end

def parse_articles(doc)
  all=get_rows(doc)
  articles = []
  all.each { |b|
    dt = get_date(b)
    href=get_link(b)
    hlt=get_headline(b)
    hlt=kill_gremlins(hlt)
    puts "found: #{hlt}" if $debug == 1
    txt=get_description(b)
    
    parts=dt.split('/')
    #updated=Date.parse(dt).strftime("%Y-%m-%dT%H:%I:%S%z")
    updated=Time.parse(dt).xmlschema
    articles << {:title=>h(hlt), :body=>txt, :updated=>updated, :permalink=>href}
  }
  return articles
end

def main

  if ARGV.length != 1
    puts "Usage: #{$0} suffix"
    exit(1)
  end
  name = ARGV[0]
  puts "Using #{name}" if $debug == 1
  base = "http://www.cbsnews.com/1770-5_162-0.html?query=#{CGI.escape name}&tag=srch&searchtype=cbsSearch&tag=mwuser&sort=updateDate%20desc"
  puts "Base = #{base}" if $debug == 1
  cachedir = './cache'
  digestfile = cachedir+"/#{name}.digest"
  unless File.directory? cachedir
    Dir.mkdir cachedir
  end
  
  if File.file? digestfile
    cached_digest = File.open(digestfile).read.chomp
  else
    cached_digest = 0
  end
  uagent="Mozilla/5.0 (Windows NT 5.1) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.106 Safari/535.2"
  referer = "http://www.cbsnews.com/"
  data = URI(base).read("User-Agent" => uagent,"Referer" => referer)
  dgst = MD5.new(data).hexdigest
  STDERR.puts "Digest = #{dgst}" if $debug == 1
  
  if(false) # turn this on later
  if(dgst == cached_digest)
    STDERR.puts "Nothing changed, not processing!" if $debug == 1
    exit(0)
  else
    c = File.open(digestfile, "w").write(dgst)
  end
  end
  doc = Nokogiri(data)
  
  rssdata=  parse_articles(doc)
  
  if $debug == 1
      rssdata.each{|f|
      puts f[:title]
      }
  end
  
  o=File.open("/home/amitc/chakradeo.net/feeds/#{name}.atom",'w')
  generate_atom rssdata,o,name, base
  o.close
  #system "/home/spacefra/vir/bin/python pubsubhubbub_publish.py http://chakradeo.net/feeds/#{ERB::Util.u name}.atom"
end

def generate_atom(rssdata,hdl, name, base)
  temp = ERB.new(File.open('atom.rxml').read)
  feed_id = h(base)
  feed_title = "CBS News Columns: #{name.capitalize}"
  feed_updated = rssdata[0][:updated]
  feed_link = "http://chakradeo.net/feeds/#{ERB::Util.u name}.atom"
  feed_author = name
  feed_entries = rssdata
  
  hdl.puts(temp.result(binding()))
end

if __FILE__ == $0
    main
end
