require 'open-uri'
require 'rubygems'
require 'hpricot'
require 'md5'
require 'erb'
require 'cgi'

def h(txt)
  CGI.escapeHTML txt
end

#require 'iconv'
#$KCODE = 'u'
#require 'jcode'

require 'rexml/encoding'

class Dummy 
    include REXML::Encoding
end

class UString < String
   # Show u-prefix as in Python
   def inspect; "u#{ super }" end

   # Count multibyte characters
   def length; self.scan(/./).length end

   # Reverse the string
   def reverse; self.scan(/./).reverse.join end
 end

 module Kernel
   def u( str )
     UString.new str.gsub(/U\+([0-9a-fA-F]{4,4})/u){["#$1".hex ].pack('U*')}
   end
 end 


$debug = ENV['DEBUG'] || 0
$make_permalink = 1


cp1252 = {
    # from http=>//www.microsoft.com/typography/unicode/1252.htm
    "\x80"=> "U+20AC", # EURO SIGN
    "\x82"=> "U+201A", # SINGLE LOW-9 QUOTATION MARK
    "\x83"=> "U+0192", # LATIN SMALL LETTER F WITH HOOK
    "\x84"=> "U+201E", # DOUBLE LOW-9 QUOTATION MARK
    "\x85"=> "U+2026", # HORIZONTAL ELLIPSIS
    "\x86"=> "U+2020", # DAGGER
    "\x87"=> "U+2021", # DOUBLE DAGGER
    "\x88"=> "U+02C6", # MODIFIER LETTER CIRCUMFLEX ACCENT
    "\x89"=> "U+2030", # PER MILLE SIGN
    "\x8A"=> "U+0160", # LATIN CAPITAL LETTER S WITH CARON
    "\x8B"=> "U+2039", # SINGLE LEFT-POINTING ANGLE QUOTATION MARK
    "\x8C"=> "U+0152", # LATIN CAPITAL LIGATURE OE
    "\x8E"=> "U+017D", # LATIN CAPITAL LETTER Z WITH CARON
    "\x91"=> "U+2018", # LEFT SINGLE QUOTATION MARK
    "\x92"=> "U+2019", # RIGHT SINGLE QUOTATION MARK
    "\x93"=> "U+201C", # LEFT DOUBLE QUOTATION MARK
    "\x94"=> "U+201D", # RIGHT DOUBLE QUOTATION MARK
    "\x95"=> "U+2022", # BULLET
    "\x96"=> "U+2013", # EN DASH
    "\x97"=> "U+2014", # EM DASH
    "\x98"=> "U+02DC", # SMALL TILDE
    "\x99"=> "U+2122", # TRADE MARK SIGN
    "\x9A"=> "U+0161", # LATIN SMALL LETTER S WITH CARON
    "\x9B"=> "U+203A", # SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
    "\x9C"=> "U+0153", # LATIN SMALL LIGATURE OE
    "\x9E"=> "U+017E", # LATIN SMALL LETTER Z WITH CARON
    "\x9F"=> "U+0178", # LATIN CAPITAL LETTER Y WITH DIAERESIS
}

$CP1252 = cp1252.keys.join
$UTF = cp1252.values.join

def parse_articles(doc)
  box=doc.at "#box_left"
  all=box/"div.listing_content"
  # Dumb hack
  snap=0
  articles = []
  all.each { |b|
    c=b.at("h5")
    href=h(c.at("a")['href'])
    if $make_permalink == 1 and /.*news.*\/\d+\//.match href
      href = href+"0"
    end
    hlt=c.at("a").html
    txt=b.children.last.to_s
    #txt = Iconv.iconv("UTF-8", "CP1252", txt+' ')
    #txt = Iconv.iconv("UTF-8//IGNORE", "WINDOWS-1252", txt+' ')
    #txt = Iconv.iconv("UTF-8//IGNORE", "UTF-8", txt+' ')
    #ic=Iconv.new('UTF-8//IGNORE', 'WINDOWS-1252')
    #txt = ic.iconv(txt+' ')[0..-2]
    
    #txt.tr!($CP1252,u($UTF))


    d=Dummy.new
    d.encoding='cp-1252'
    txt = d.decode_cp1252(u txt)

    parts=b.at("p").children.last.to_s.split
    parts.last.sub!(/\'/,'20')
    updated=Date.parse(parts.join(' ')).strftime("%Y-%m-%dT06:00:#{sprintf("%02d",snap)}Z")
    #snap=snap-1
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
uagent="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/530.5 (KHTML, like Gecko) Chrome/2.0.172.31 Safari/530.5"
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

o=File.open("/home/spacefra/www/feeds/#{name}.atom",'w')
generate_atom rssdata,o,name

end

def generate_atom(rssdata,hdl, name)
temp = ERB.new(File.open('atom.rxml').read)
feed_id = "http://www.iexpress.com/columnist/#{name}"
feed_title = "IE Columnist: #{name.capitalize}"
feed_updated = rssdata[0][:updated]
feed_link = "http://chakradeo.net/feeds/#{name}.atom"
feed_author = "Amit"
feed_entries = rssdata

hdl.puts(temp.result(binding()))
end

if __FILE__ == $0
    main
end
