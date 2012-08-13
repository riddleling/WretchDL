#
#  application.rb - The WretchDL Project
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


require 'rubygems' # disable this for a deployed application
require 'hotcocoa'
require 'fileutils'

SOURCE_DIR = File.expand_path(File.dirname(__FILE__))
require SOURCE_DIR + '/wretch_albums_info'


class WretchDL
    include HotCocoa

    def initialize
        @wretch_id = ""
        @last_wretch_id = ""
        @albums = []
        @pages_number = 0
        @last_pages_number = 0
        @is_downloading = false
    end

    def start
        application name: 'WretchDL' do |app|
            app.delegate = self
            @window = window(size: [450, 430], center: true, title: 'WretchDL') do |win|
                win.will_close { exit }
                
                # Setup top layout_view
                top_view = layout_view(:size => [0, 30], 
                                       :mode => :horizontal, 
                                       :layout => {:start => false, 
                                                   :expand => [:width]}) do |view|
                    view.margin = 5
                    view.spacing = 5
                    view << label(:text => ' Wretch Account :', :layout => {:align => :center})
                    view << @field = text_field(:layout => {:expand => [:width], :align => :center})
                    view << @go_button = button(:title => 'Go', :layout => {:align => :center})
                    view << @search_progress = progress_indicator(:frame => [0, 0, 20, 20], :layout =>{:align => :center})
                    @search_progress.style = :spinning
                    @search_progress.hide
                end
                win << top_view
                @go_button.on_action { search_albums }
                
                
                # Setup center layout_view
                center_view = layout_view(:size => [0, 300],
                                          :mode => :horizontal,
                                          :layout => {:start => false,
                                                      :expand => [:width]}) do |view|
                    view.spacing = 11
                    view.margin = 5
                    
                    # Setup cover image:
                    view << layout_view(:size => [100, 300],
                                        :mode => :vertical,
                                        :layout => {:align => :top}) do |vert|
                        vert.spacing = 3
                        vert.margin = 0
                        
                        vert << @cover_image = image_view(:frame => [0, 0, 100, 100], 
                                                          :frame_style => :bezel,
                                                          :layout => {:start => false, :align => :left})
                        vert << @pictures_label = label(:text => "? pictures",
                                                        :text_align => :center,
                                                        :layout => {:start => false,
                                                                    :expand => [:width]})
                    end
                    
                    # Setup ScrollView and TableView
                    view << layout_view(:size => [0, 270],
                                        :mode => :vertical,
                                        :layout => {:expand => [:width, :height]}) do |vert|
                        vert.spacing = 3
                        vert.margin = 0
                        
                        vert << scroll_view(:layout =>{:start => false, :expand => [:width, :height]}) do |scroll|
                            scroll.setAutohidesScrollers(true)
                            scroll.setBorderType(NSBezelBorder)
                        
                            scroll << @table = table_view(:columns => [column(:id => :album_name, :title =>'Album Name')]) do |table|
                                table.setUsesAlternatingRowBackgroundColors(true)
                                table.setGridStyleMask(NSTableViewDashedHorizontalGridLineMask)
                                table.setSelectionHighlightStyle(NSTableViewSelectionHighlightStyleSourceList)
                            end
                        end
                        
                        vert << layout_view(:size => [0, 30],
                                            :mode => :horizontal,
                                            :layout => {:start => false,
                                                        :expand => [:width]}) do |hori|
                            hori.spacing = 0
                            hori.margin = 2
                            hori << @previous_page_button = button(:title => "<-", :layout => {:align => :center})
                            hori << @pages_number_label = label(:text => "Page:#{@pages_number}",
                                                                :text_align => :center,
                                                                :layout => {:expand => [:width], :align => :top})
                            hori << @next_page_button = button(:title => "->", :layout => {:align => :center})
                        end
                    end
                end
                @table.dataSource = self
                @table.delegate =self
                @previous_page_button.enabled = false
                @next_page_button.enabled = false
                @previous_page_button.on_action { previous_page }
                @next_page_button.on_action { next_page }
                win << center_view
                
                
                # Setup bottom layout_view
                bottom_view = layout_view(:size => [0, 60],
                                          :mode => :vertical,
                                          :layout => {:start => false,
                                                      :expand => [:width]}) do |view|
                    view.margin = 2
                    view.spacing = 0
                    
                    view << layout_view(:size => [0, 30],
                                        :mode => :horizontal,
                                        :layout => {:start => false,
                                                    :expand => [:width]}) do |hori|
                        hori.margin = 0
                        hori.spacing = 6
                        hori << @download_progress = progress_indicator(:layout => {:expand => [:width], :align => :center})
                        @download_progress.hide
                        hori << @download_button = button(:title => 'Download', :layout => {:align => :center})
                    end
                    view << @status_label = label(:text => "", 
                                                  :layout => {:start => false,
                                                              :align => :top,
                                                              :expand => [:width]})
                end
                win << bottom_view
                @download_button.on_action { downloading }
                @download_button.enabled = false
            end
        end
    end


    def search_albums
        @last_wretch_id = @wretch_id
        @wretch_id = @field.stringValue
        @last_pages_number = @pages_number
        @pages_number = 1
        update_table
    end
    
    def previous_page
        if @pages_number > 1
            @pages_number -= 1
            update_table
        end
    end
    
    def next_page
        @pages_number += 1
        update_table
    end
    
    def update_table
        @search_progress.show
        @search_progress.start
        
        queue = Dispatch::Queue.new('com.lingdev.WretchDL.update_table_data')
        queue.async do
            begin
                albums_info = WretchAlbumsInfo.new(@wretch_id)
                @albums = albums_info.list_of_page(@pages_number)
            rescue OpenURI::HTTPError => e
                @wretch_id = @last_wretch_id
                @pages_number = @last_pages_number
                Dispatch::Queue.main.async do
                    show_error_alert("#{e.message}")
                end
                return
            rescue URI::InvalidURIError => e
                @wretch_id = @last_wretch_id
                @pages_number = @last_pages_number
                Dispatch::Queue.main.async do
                    show_error_alert("#{e.message}")
                end
                return
            end

            Dispatch::Queue.main.async do
                @table.reloadData
                @table.deselectAll(self)
                @download_button.enabled = false
                @cover_image.setImage(nil)
                @pictures_label.stringValue = "? pictures"
                @pages_number_label.stringValue = "Page:#{@pages_number}"
                @search_progress.stop
                @search_progress.hide
                
                if @pages_number <= 1
                    if @previous_page_button.isEnabled
                        @previous_page_button.enabled = false
                    end
                else
                    if not @previous_page_button.isEnabled
                        @previous_page_button.enabled = true
                    end
                end
                
                if albums_info.page_next?
                    if not @next_page_button.isEnabled
                        @next_page_button.enabled = true
                    end
                else
                    if @next_page_button.isEnabled
                        @next_page_button.enabled = false
                    end
                end
            end
        end
    end
    

    def downloading
        @is_downloading = !@is_downloading
        
        if @is_downloading
            if @table.selectedRow != -1
                t_row = @table.selectedRow
                home_path = NSHomeDirectory()
                dl_dir_path = File.join(home_path, 'Downloads', 'WretchAlbums', @albums[t_row].id, @albums[t_row].name)
                make_dl_dir(dl_dir_path)
            
                @table.enabled = false
                @go_button.enabled = false
                if @previous_page_button.isEnabled
                    is_previous_page_enabled = true
                    # Off @previous_page_button
                    @previous_page_button.enabled = false
                else
                    is_previous_page_enabled = false
                end
                
                if @next_page_button.isEnabled
                    is_next_page_enabled = true
                    # Off @next_page_button
                    @next_page_button.enabled = false
                else
                    is_next_page_enabled = false
                end
                
                max_steps = @albums[t_row].pictures
                @status_label.stringValue = "Downloading... (0/#{max_steps})"
                @download_button.title = "Stop!"
                if not @download_progress.isIndeterminate
                    @download_progress.setIndeterminate(true)
                end
                @download_progress.show
                @download_progress.start
                
                queue = Dispatch::Queue.new('com.lingdev.WretchDL.download_files')
                queue.async do
                    urls = @albums[t_row].photos_urls
                    
                    # Update GUI
                    Dispatch::Queue.main.async do
                        @download_progress.minValue = 0.0
                        @download_progress.maxValue = urls.size.to_f
                        @download_progress.reset
                        @download_progress.stop
                        @download_progress.setIndeterminate(false)
                    end
                
                    urls.each_with_index do |photo_url, index|
                        file_url = photo_url.to_file_url
                        if not file_url.empty?
                            download_file(file_url, dl_dir_path)
                            break if not @is_downloading
                            # Update GUI
                            Dispatch::Queue.main.async do
                                steps = index + 1
                                @download_progress.value = steps
                                @status_label.stringValue = "Downloading... (#{steps}/#{max_steps})"
                            end
                        end
                        sleep 1
                    end
                    # Update GUI
                    Dispatch::Queue.main.async do
                        @download_progress.hide
                        @table.enabled = true
                        @go_button.enabled = true
                        
                        @previous_page_button.setEnabled(true) if is_previous_page_enabled
                        @next_page_button.setEnabled(true) if is_next_page_enabled
                        @download_button.setEnabled(true) if not @download_button.isEnabled
                        
                        @is_downloading = false
                        @download_button.title = "Download"
                        @status_label.stringValue = "Downloaded to the ~/Downloads/WretchAlbums/"
                    end
                end 
            end
        else
            @status_label.stringValue = "Stoping..."
            @download_button.enabled = false
        end
    end
    
    
    def download_file(file_url, dl_dir_path)
        file_url =~ %r!http://.+/(.+\.jpg)?.+!
        file_name = $1
        referer_url = "http://www.wretch.cc/album/"
        # "curl --referer #{referer_url} '#{file_url}' -o #{file_name}"
    
        task = NSTask.alloc.init
        task.setLaunchPath("/usr/bin/curl")
        task.setCurrentDirectoryPath(dl_dir_path)
    
        task_args = ["--referer", referer_url, file_url, "-o", file_name]
        task.setArguments(task_args)
    
        task.launch
        task.waitUntilExit
        
        task_status = task.terminationStatus
    
        if task_status != 0
            puts "Download fail: #{file_url}"
        end
    end
    
    def make_dl_dir(dir_path)
         #puts "dl_dir: #{dir_path}"
        FileUtils.mkdir_p(dir_path)
    end
    
    def numberOfRowsInTableView(view)
        @albums.size
    end
    
    def tableView(view, objectValueForTableColumn: column, row: index)
        @albums[index].name
    end
    
    def tableViewSelectionDidChange(notification)
        if @table.selectedRow != -1
            t_row = @table.selectedRow
             #puts "selected row: #{t_row}"
            
            if @albums[t_row].cover_url
                img = NSImage.alloc.initWithContentsOfURL(NSURL.alloc.initWithString(@albums[t_row].cover_url))
                @cover_image.setImage(img)
                @cover_image.setImageScaling(NSImageScaleProportionallyUpOrDown)
            else
                @cover_image.setImage(nil)
            end
            @pictures_label.stringValue = "#{@albums[t_row].pictures} pictures"
            @download_button.enabled = true
        end 
    end
    
    def show_error_alert(message)
        alert = NSAlert.alloc.init
        alert.setMessageText("Error!")
        alert.setInformativeText(message)
        alert.beginSheetModalForWindow(@window, modalDelegate:self, didEndSelector:nil, contextInfo:nil)
        @search_progress.stop
        @search_progress.hide
    end
    
    # help menu item
    def on_help(menu)
    end

    # This is commented out, so the minimize menu item is disabled
    #def on_minimize(menu)
    #end

    # window/zoom
    #def on_zoom(menu)
    #end
end

WretchDL.new.start
