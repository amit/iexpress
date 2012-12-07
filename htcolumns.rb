require 'open-uri'
require 'rubygems'
require 'hpricot'
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
$make_permalink = 1


def parse_articles(doc)
  all=doc/"div.nikic"
  # Dumb hack
  snap=59
  articles = []
  all.each { |b|
    href=h(b.at("a")['href'])
    hlt=b.at("a").html
    hlt=kill_gremlins(hlt)
    puts "found: #{hlt}" if $debug == 1
    txt=b.at(".nikicker").inner_text
    txt=kill_gremlins(txt)
    
    parts=b.parent.parent.at("div.Date").at("span").inner_text.split
    #parts.last.sub!(/\'/,'20')
    updated=Date.parse(parts.join(' ')).strftime("%Y-%m-%dT00:01:#{sprintf("%02d",snap)}+05:30")
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
    puts "Usage: #{$0} columnist"
    exit(1)
  end
  name = ARGV[0]
  puts "Using #{name}" if $debug == 1
  base = "http://www.hindustantimes.com/Search/Search.aspx?op=Story&q=#{CGI.escape name}"
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
  #uagent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/532.5 (KHTML, like Gecko) Chrome/4.1.249.1064 Safari/532.5"
  uagent="Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.13 (KHTML, like Gecko) Chrome/24.0.1290.1 Safari/537.13"
  data = URI(base).read("User-Agent" => uagent,"Referer" => 'http://www.iexpress.com/')
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
  doc = Hpricot(data)
  
  rssdata=  parse_articles(doc)
  
  if $debug == 1
      rssdata.each{|f|
      puts f[:title]
      }
  end
  
  o=File.open("/home/amitc/chakradeo.net/feeds/#{name}.atom",'w')
  generate_atom rssdata,o,name
  
end

def generate_atom(rssdata,hdl, name)
  temp = ERB.new(File.open('atom.rxml').read)
  #feed_id = "http://www.iexpress.com/columnist/#{CGI.escape name}"
  feed_id = "http://www.hindustantimes.com/Search/Search.aspx?op=Story&amp;q=#{CGI.escape name}"
  feed_title = "HT Columnist: #{name.capitalize}"
  feed_updated = rssdata[0][:updated]
  feed_link = "http://chakradeo.net/feeds/#{ERB::Util.u name}.atom"
  feed_author = name
  feed_entries = rssdata
  
  hdl.puts(temp.result(binding()))
end

if __FILE__ == $0
    main
end
