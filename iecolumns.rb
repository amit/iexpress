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
    all = doc/"div.col-stories"
    # Dumb hack
    snap=59
    articles = []
    all.each { |b|
      c=b.at("h6")
      href=h(c.at("a")['href'])
      hlt=c.at("a").html
      hlt=kill_gremlins(hlt)
      txt=b.children.last.to_s
      txt=kill_gremlins(txt)
      
      parts=b.at("p").children.last.to_s.split
      parts=b.at(".date").html.to_s.split
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
  base = "http://indianexpress.com/profile/columnist/#{name}/"
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
  uagent="Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.1916.114 Safari/537.36"
  counter=0
  begin
    data = URI(base).read("User-Agent" => uagent,"Referer" => 'http://indianexpress.com/columnists/')
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
    o=File.open("/home/amitc/chakradeo.net/feeds/#{name}.atom",'w')
    generate_atom rssdata,o,name
    o.close
  end
end

def generate_atom(rssdata,hdl, name)
  temp = ERB.new(File.open('atom.rxml').read)
  feed_id = "http://indianexpress.com/profile/columnist/#{name}"
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
