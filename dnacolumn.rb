require 'open-uri'
require 'rubygems'
require 'hpricot'
require 'md5'
require 'erb'

$debug = 0

def parse_dna_articles(doc)
  articles=[]
  snap=59
  items=doc/"//div[@class1=content]"
  items.each{ |b|
    txt=b.at("div.syn2").html
    hlt=b.at("h4/a").html
    href=b.at("h4/a")["href"]
    href="http://www.dnaindia.com"+href
    dt=Date.parse((b/"div").last.html)
    updated=dt.strftime("%Y-%m-%dT06:00:#{sprintf("%02d",snap)}Z")
    snap=snap-1
    articles << {:title=>hlt, :body=>txt, :updated=>updated, :permalink=>href}
  }
  return articles
end

def parse_articles(doc)
  box=doc.at "#box_left"
  all=box/"div.listing_content"
  # Dumb hack
  snap=59
  articles = []
  all.each { |b|
    c=b.at("h5")
    href=c.at("a")['href']
    if /.*news.*\/\d+\//.match href
      href = href+"0"
    end
    hlt=c.at("a").html
    txt=b.children.last.to_s
    parts=b.at("p").children.last.to_s.split
    parts.last.sub!(/\'/,'20')
    updated=Date.parse(parts.join(' ')).strftime("%Y-%m-%dT06:00:#{sprintf("%02d",snap)}Z")
    snap=snap-1
    articles << {:title=>hlt, :body=>txt, :updated=>updated, :permalink=>href}
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
base = "http://www.dnaindia.com/columns/#{name}/"
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
data = URI(base).read("User-Agent" => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.9) Gecko/20071025 Firefox/2.0.0.9',"Referer" => 'http://www.iexpress.com/')
#data = File.read('index.html')
dgst = MD5.new(data).hexdigest
STDERR.puts "Digest = #{dgst}" if $debug == 1

if(true) # turn this on later
if(dgst == cached_digest)
  STDERR.puts "Nothing changed, not processing!" if $debug == 1
  exit(0)
else
  c = File.open(digestfile, "w").write(dgst)
end
end
doc = Hpricot(data)

rssdata=  parse_dna_articles(doc)

#rssdata.each{|f|
#puts f[:title]
#}

o=File.open("/home/spacefra/www/feeds/#{name}.atom",'w')
generate_atom rssdata,o,name

end

def generate_atom(rssdata,hdl, name)
temp = ERB.new(File.open('atom.rxml').read)
feed_id = "http://www.dnaindia.com/columns/#{name}/"
feed_title = "Columnists: #{name}"
feed_updated = rssdata[0][:updated]
feed_link = "http://chakradeo.net/feeds/#{name}.atom"
feed_author = "Amit"
feed_entries = rssdata

hdl.puts(temp.result(binding()))
end

if $0 == __FILE__
  main
end
