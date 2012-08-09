require 'rubygems' # disable this for a deployed application
require 'hotcocoa'

SOURCE_DIR = File.expand_path(File.dirname(__FILE__))
require SOURCE_DIR + '/wretch_albums_info'


class WretchDL
    include HotCocoa

    def initialize
        @albums = []
        @pages_number = 0
    end

    def start
        application name: 'WretchDL' do |app|
            app.delegate = self
            window(size: [380, 430], center: true, title: 'WretchDL') do |win|
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
                @go_button.on_action { search_albums_list }
                
                
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
                             #hori << @pages_number_label = label(:text => "Page:1", :layout => {:expand => [:width], :align => :top})
                            hori << @page_up_button = button(:title => "<-", :layout => {:align => :center})
                            hori << @pages_number_label = label(:text => "Page:#{@pages_number}",
                                                                :text_align => :center,
                                                                :layout => {:expand => [:width], :align => :top})
                            hori << @page_down_button = button(:title => "->", :layout => {:align => :center})
                        end
                    end
                end
                @table.dataSource = self
                @table.delegate =self
                @page_up_button.enabled = false
                @page_down_button.enabled = false
                @page_up_button.on_action { page_up }
                @page_down_button.on_action { page_down }
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
                    view << @status_label = label(:text => "Downloading...", 
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


    def search_albums_list
        @wretch_id = @field.stringValue
        @pages_number = 1
        update_table
    end
    
    def page_up
        if @pages_number > 1
            @pages_number -= 1
            update_table
        end
    end
    
    def page_down
        @pages_number += 1
        update_table
    end
    
    def update_table
        @search_progress.show
        @search_progress.start
        
        queue = Dispatch::Queue.new('com.lingdev.WretchDL.update_table_data')
        queue.async do
            albums_info = WretchAlbumsInfo.new(@wretch_id)
            @albums = albums_info.list_of_page(@pages_number)
            
            #@albums.each_with_index do |album, i|
            #    puts "#{i}. #{album.name} (#{album.pictures}p)"
            #end
            
            Dispatch::Queue.main.async do
                @table.reloadData
                @table.deselectAll(self)
                @download_button.enabled = false
                @search_progress.stop
                @search_progress.hide
                @cover_image.setImage(nil)
                @pictures_label.stringValue = "? pictures"
                @pages_number_label.stringValue = "Page:#{@pages_number}"
                
                if @pages_number <= 1
                    if @page_up_button.isEnabled
                        @page_up_button.enabled = false
                    end
                else
                    if not @page_up_button.isEnabled
                        @page_up_button.enabled = true
                    end
                end
                
                if albums_info.next_page?
                    if not @page_down_button.isEnabled
                        @page_down_button.enabled = true
                    end
                else
                    if @page_down_button.isEnabled
                        @page_down_button.enabled = false
                    end
                end
            end
        end
    end
    

    def downloading
        puts "Downloading..."
        if @table.selectedRow != -1
            i = @table.selectedRow
            make_dl_dir(@albums[i].id, @albums[i].name)
        end
    end
    
    def make_dl_dir(id_name, album_name)
        home_path = NSHomeDirectory()
        dl_dir = File.join(home_path, 'Downloads', 'WretchAlbums', id_name, album_name)
        puts "dl_dir: #{dl_dir}"
        
    end
    
    def numberOfRowsInTableView(view)
        @albums.size
    end
    
    def tableView(view, objectValueForTableColumn: column, row: index)
        @albums[index].name
    end
    
    def tableViewSelectionDidChange(notification)
        if @table.selectedRow != -1
            i = @table.selectedRow
            puts "selected row: #{i}"
            
            if @albums[i].cover_url
                img = NSImage.alloc.initWithContentsOfURL(NSURL.alloc.initWithString(@albums[i].cover_url))
                @cover_image.setImage(img)
                @cover_image.setImageScaling(NSImageScaleProportionallyUpOrDown)
            else
                @cover_image.setImage(nil)
            end
            @pictures_label.stringValue = "#{@albums[i].pictures} pictures"
            @download_button.enabled = true
        end 
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
