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

$debug = ENV['DEBUG'] || 1
$make_permalink = 1


def parse_articles(doc)
  all=doc/"div#mstarcontent table tbody tr"
  # Dumb hack
  snap=59
  articles = []
  all.each { |b|
    td=b.at("td[@headers='article_title']")
    coll = b.at("td[@headers='article_dept']").text
    dt = b.at("td[@headers='article_date']").text
    href=h(td.at("a")['href'])
    hlt=td.text
    hlt=kill_gremlins(hlt)
    puts "found: #{hlt}" if $debug == 1
    txt="Article: \"#{h td.text}\" from the collection \"#{h coll}\""
    txt=kill_gremlins(txt)
    
    parts=dt.split('/')
    #parts.last.sub!(/\'/,'20')
    updated=Date.parse(parts.join(' ')).strftime("%Y-%m-%dT00:01:#{sprintf("%02d",snap)}-07:00")
    snap=snap-1
    if snap==0
      snap = 60
    end
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
  base = "http://www.morningstar.com/articles/author/#{CGI.escape name}"
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
  data = URI(base).read("User-Agent" => uagent,"Referer" => 'http://www.morningstar.com/')
  #data = File.read('index.html')
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
  
  o=File.open("/home/spacefra/www/feeds/#{name}.atom",'w')
  generate_atom rssdata,o,name
  o.close
  system "/home/spacefra/vir/bin/python pubsubhubbub_publish.py http://chakradeo.net/feeds/#{ERB::Util.u name}.atom"
end

def generate_atom(rssdata,hdl, name)
  temp = ERB.new(File.open('atom.rxml').read)
  #feed_id = "http://www.iexpress.com/columnist/#{CGI.escape name}"
  feed_id = "http://www.morningstar.com/articles/author/#{CGI.escape name}"
  feed_title = "Morningstar Columns: #{name.capitalize}"
  feed_updated = rssdata[0][:updated]
  feed_link = "http://chakradeo.net/feeds/#{ERB::Util.u name}.atom"
  feed_author = name
  feed_entries = rssdata
  
  hdl.puts(temp.result(binding()))
end

if __FILE__ == $0
    main
end
