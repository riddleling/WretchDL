#
#  wretch_albums_info.rb
#
#
#  Copyright (c) 2012 Wei-Chen Ling.
# 
#  Permission is hereby granted, free of charge, to any person
#  obtaining a copy of this software and associated documentation
#  files (the "Software"), to deal in the Software without
#  restriction, including without limitation the rights to use,
#  copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following
#  conditions:
#
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#

require 'open-uri'

##
#  WretchPhotoURL Class
#
class WretchPhotoURL
  attr_accessor :photo_url
  
  def initialize(photo_url)
    @photo_url = photo_url
  end
  
  def to_file_url
    page_html = open(@photo_url).read
    
    file_url = ""
    page_html.each_line do |line|
      if line =~ /<img id='DisplayImage' src='([^']+)' /
        file_url = Regexp.last_match[1]
      elsif line =~ /<img class='displayimg' src='([^']+)' /
        file_url = Regexp.last_match[1]
      end
    end
    file_url
  end
end


##
#  WretchAlbum Class
#
class WretchAlbum
  attr_accessor :id, :number, :name, :pictures, :cover_url
  
  def initialize(id, number, name)
    @id, @number, @name = id, number, name
    @pictures = 0
  end
  
  def photos_urls
    album_url = "http://www.wretch.cc/album/album.php?id=#{@id}&book=#{@number}"
    i = 1
    is_page_next = true
    urls = []
    while is_page_next do
      page_html = open(album_url).read
    
      urls.concat(get_photo_url_list(page_html))
      i += 1
      is_page_next = false
      # page next?
      page_html.each_line do |line|
        if line =~ /(album\.php\?id=#{@id}&book=#{@number}&page=#{i})/
          album_url = "http://www.wretch.cc/album/album.php?id=#{@id}&book=#{@number}&page=#{i}"
          is_page_next = true
          break
        end
      end
    end
    urls
  end
  
  private
  def get_photo_url_list(page_html)
    urls = []
    page_html.each_line do |line|
      if line =~ /<a href="\.\/(show.php\?i=#{@id}&b=#{@number}&f=\d+&p=\d+&sp=\d+)".+><img src=/
        photo_url = WretchPhotoURL.new("http://www.wretch.cc/album/#{Regexp.last_match[1]}")
        urls.push(photo_url)
      end
    end
    urls
  end
end


##
#  WretchAlbumsInfo Class
#
class WretchAlbumsInfo
  attr_accessor :wretch_id

  def initialize(wretch_id)
    @wretch_id = wretch_id
    @is_page_next = false
  end

  def list_of_page(num)
    @page_number = num
    wretch_url = "http://www.wretch.cc/album/#{@wretch_id}"
    if @page_number >= 2 
      wretch_url << "&page=#{@page_number}"
    end

    page_html = open(wretch_url).read
    albums = []

    # get album number, name, and pictures number
    page_html.each_line do |line|
      if line =~ /<a href="\.\/album\.php\?id=#{@wretch_id}&book=(\d+)">(.+)<\/a>/
        albums << WretchAlbum.new(@wretch_id, Regexp.last_match[1], Regexp.last_match[2])
      end
      
      if line =~ /(\d+)pictures\s*?<\/font>/
        albums[-1].pictures = Regexp.last_match[1]
      end
    end
    
    # get cover url
    covers = {}
    page_html.each_line do |line|
      if line =~ %r!<img src="(http://.+/#{@wretch_id}/(\d+)/thumbs/.+)" border="0" alt="Cover"/>!
        key = $2.to_sym
        covers[key] = $1
      elsif line =~ %r!<img src="(http://.+/#{@wretch_id.downcase}/(\d+)/thumbs/.+)" border="0" alt="Cover"/>!
        key = $2.to_sym
        covers[key] = $1
      end
    end
    
    albums.each do |a|
      key = a.number.to_sym
      a.cover_url = covers[key]
    end
    
    # page next?
    page_html.each_line do |line|
      if line =~ %r!<a id='next' href="#{@wretch_id}&page=#{@page_number+1}" class="">!
        @is_page_next = true
        break
      end
    end
    albums
  end
  
  def page_next?
    @is_page_next
  end
end
