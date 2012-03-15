require 'rubygems'
require 'mechanize'

class SvtPlay
	attr_accessor :download_dir
	
	def initialize
		@download_dir = "/tmp/svtplay/"
		@agent = Mechanize.new
	end

	def download_clip(clip_url)
		doc = @agent.get(clip_url)
		doc.search("param[name='flashvars']").each do |param|
			if param[:value].match(/url:(.+?),bitrate:/)
				rtmp = $1
				download rtmp unless clip_exists? rtmp
				break
			end
		end
	end

	def search(search_str)
		@search_str = search_str.gsub(' ', '+')
		url = "http://svtplay.se/sok?ps,s,1,#{escape @search_str},full"
		doc = @agent.get(url)
		clip_links = doc.search("ul.list.small li a.overlay.tooltip")
		clip_links.each do |ahref|
			if ahref.text.match(/Sändes/)
				clip = ahref[:href]
				puts "Found clip #{clip}"
				download_clip(clip)			
			end
		end
		return clip_links.size
	end

	private
	def download_dir
		"#{@download_dir}/#{@search_str}"
	end
	
	def create_download_dir
		Dir.mkdir download_dir unless FileTest.exists? download_dir
	end
	
	def escape(str)
		s = str.gsub(' ', '+')
		s = s.gsub("ä", '%E4')
		s = s.gsub("å", '%E5')
		s = s.gsub("ö", '%F6')
		s
	end

	def mp4_filename_from_url(url)
		if url
			pieces = url.split("/")
			return pieces.last
		end
		return ""
	end

	def clip_exists?(rtmp)
		dst = "#{download_dir + "/" + mp4_filename_from_url(rtmp)}"
		if FileTest.exist?(dst)
			p "Skipping #{dst}"
			return true
		end
		return false
	end


	def download(rtmp)
		create_download_dir
		dst = "#{download_dir + "/" + mp4_filename_from_url(rtmp)}"
		p "Downloading #{rtmp} to #{dst}"
		system("rtmpdump", "-r", rtmp, "-o", dst)
	end
	
end

if ARGV.size == 2
	begin
		s = SvtPlay.new
		s.download_dir = ARGV.last
		if 0 == s.search(ARGV.first)
			puts "No clips found for search string \"#{ARGV.first}\""
		end
	rescue Errno::EACCES, Errno::ENOENT => e
		puts e.message 
	end
else
	puts "SVT Play episode downloader ALPHA"
	puts "Downloads SVT Play clips which matches given search string"
	puts "Usage:"
	puts "ruby svtplay.rb \"search string\" download_path" 
	puts "Example:"
	puts "ruby svtplay.rb \"äkta människor\" /tmp/svtplay/" 
end
