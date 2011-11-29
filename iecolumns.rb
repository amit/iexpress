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
  box=doc.at "#box_left"
  if box
    all=box/"div.listing_content"
    # Dumb hack
    snap=59
    articles = []
    all.each { |b|
      c=b.at("h5")
      href=h(c.at("a")['href'])
      if $make_permalink == 1 and /.*news.*\/\d+\//.match href
        href = href+"0"
      end
      hlt=c.at("a").html
      hlt=kill_gremlins(hlt)
      txt=b.children.last.to_s
      txt=kill_gremlins(txt)
      
      parts=b.at("p").children.last.to_s.split
      parts.last.sub!(/\'/,'20')
      updated=Date.parse(parts.join(' ')).strftime("%Y-%m-%dT00:01:#{sprintf("%02d",snap)}+05:30")
      snap=snap-1
      if snap==0
        snap = 60
      end
      articles << {:title=>h(hlt), :body=>txt, :updated=>updated, :permalink=>href}
    }
    return articles
  end
end

def main
  if ARGV.length != 1
    puts "Usage: #{$0} columnist"
    exit(1)
  end
  name = ARGV[0]
  puts "Using #{name}" if $debug == 1
  base = "http://www.indianexpress.com/columnist/#{name}/"
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
  uagent="Mozilla/5.0 (Windows NT 6.1; rv:6.0.1) Gecko/20100101 Firefox/6.0.1"
  counter=0
  begin
    data = URI(base).read("User-Agent" => uagent,"Referer" => 'http://www.iexpress.com/')
  rescue Exception=>e
    puts "Encountered error: #{e}, retry: #{counter}"
    counter += 1
    if counter < 5
      sleep (1+rand(4))
      retry
    else
      #throw "Exception - Repeated EOFError!"
      exit
    end
  end
  dgst = MD5.new(data).hexdigest
  STDERR.puts "Digest = #{dgst}" if $debug == 1
  
  if(true) # turn this on later
    if(dgst == cached_digest)
      STDERR.puts "Nothing changed, not processing!" if $debug == 1
      exit(0)
    else
      File.open(digestfile, "w") do |f|
        f.write(dgst)
      end
    end
  end
  doc = Hpricot(data)
  
  rssdata=  parse_articles(doc)
  
  if $debug == 1
      rssdata.each{|f|
      puts f[:title]
      }
  end
  
  if rssdata
    o=File.open("/home/spacefra/www/feeds/#{name}.atom",'w')
    generate_atom rssdata,o,name
    o.close
    system "/home/spacefra/vir/bin/python pubsubhubbub_publish.py http://chakradeo.net/feeds/#{ERB::Util.u name}.atom"
  end
end

def generate_atom(rssdata,hdl, name)
  temp = ERB.new(File.open('atom.rxml').read)
  feed_id = "http://www.iexpress.com/columnist/#{name}"
  feed_title = "IE Columnist: #{name.capitalize}"
  feed_updated = rssdata[0][:updated]
  feed_link = "http://chakradeo.net/feeds/#{name}.atom"
  feed_author = name
  feed_entries = rssdata
  
  hdl.puts(temp.result(binding()))
end

if __FILE__ == $0
    main
end
