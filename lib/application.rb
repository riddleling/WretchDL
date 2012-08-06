require 'rubygems' # disable this for a deployed application
require 'hotcocoa'

SOURCE_DIR = File.expand_path(File.dirname(__FILE__))
require SOURCE_DIR + '/wretch_albums_info'


class WretchDL
    include HotCocoa

    def initialize
        @albums = []
    end

    def start
        application name: 'WretchDL' do |app|
            app.delegate = self
            window(size: [600, 500], center: true, title: 'WretchDL') do |win|
                win.will_close { exit }
                
                # Setup top layout_view
                top_view = layout_view(:size => [0, 40], 
                                       :mode => :horizontal, 
                                       :layout => {:padding => 0, 
                                                   :margin => 0, 
                                                   :start => false, 
                                                   :expand => [:width]}) do |view|
                    view << label(:text => 'Wretch Account :', :layout => {:expand => [:height]})
                    view << @field = text_field(:layout => {:expand => [:width]})
                    view << @go_button = button(:title => 'Go', :layout => {:align => :center})
                    view << @search_progress = progress_indicator(:frame => [0, 0, 20, 20])
                    @search_progress.style = :spinning
                    @search_progress.hide
                end
                win << top_view
                @go_button.on_action { search_albums_list }
                
                # Setup center layout_view
                center_view = layout_view(:size => [0, 300],
                                          :mode => :horizontal,
                                          :layout => {:padding => 0,
                                                      :margin => 0,
                                                      :start => false,
                                                      :expand => [:width]}) do |view|
                    # Setup cover image:
                    view << layout_view(:size => [130, 180],
                                        :mode => :vertical,
                                        :layout => {:padding => 0,
                                                    :margin => 0,
                                                    :align => :top}) do |vert|
                        vert << @cover_image = image_view(:frame => [0, 0, 120, 120], 
                                                          :frame_style => :bezel,
                                                          :layout => {:start => false, :align => [:top, :left]})
                        vert << @pages_label = label(:text => "pages:", :layout => {:start => false, :align => :center})
                    end
                    
                    # Setup ScrollView and TableView
                    view << scroll_view(:layout =>{:expand => [:width, :height]}) do |scroll|
                        scroll.setAutohidesScrollers(true)
                        scroll.setBorderType(NSBezelBorder)
                        
                        scroll << @table = table_view(:columns => [column(:id => :album_name, :title =>'Album Name')]) do |table|
                            table.setUsesAlternatingRowBackgroundColors(true)
                            table.setGridStyleMask(NSTableViewDashedHorizontalGridLineMask)
                            table.setSelectionHighlightStyle(NSTableViewSelectionHighlightStyleSourceList)
                        end
                    end
                end
                
                @table.dataSource = self
                @table.delegate =self
                win << center_view
                
                # Setup bottom layout_view
                bottom_view = layout_view(:size => [0, 50],
                                          :mode => :vertical,
                                          :layout => {:padding => 0,
                                                      :margin => 0,
                                                      :start => false,
                                                      :expand => [:width]}) do |view|
                    view << @download_progress = progress_indicator(:layout => {:start => false, :expand => [:width, :height]})
                    @download_progress.hide
                    view << @status_label = label(:text => "Downloading...", :layout => {:start => false})
                    view << @download_button = button(:title => 'Download', :layout => {:start => false, :align => :right})
                end
                
                win << bottom_view
                @download_button.on_action { downloading }
                
            end
        end
    end


    def search_albums_list
        @search_progress.show
        @search_progress.start
        wretch_id = @field.stringValue
        queue = Dispatch::Queue.new('com.lingdev.WretchDL.search_list')
        queue.async do
            @albums = WretchAlbumsInfo.new(wretch_id).list_of_page(1)
        
            #@albums.each_with_index do |album, i|
            #    puts "#{i}. #{album.name} (#{album.pictures}p)"
            #end
            
            Dispatch::Queue.main.async do
                @table.reloadData
                @search_progress.stop
                @search_progress.hide
            end
        end
    end

    def downloading
        puts "Downloading"
    end
    
    def numberOfRowsInTableView(view)
        @albums.size
    end
    
    def tableView(view, objectValueForTableColumn: column, row: index)
        @albums[index].name
    end
    
    def tableViewSelectionDidChange(notification)
        if @table.selectedRow != -1
            puts "selected row: #{@table.selectedRow}"
            @cover_image.url = @albums[@table.selectedRow].cover_url
        end 
    end

    # help menu item
    def on_help(menu)
    end

    # This is commented out, so the minimize menu item is disabled
    #def on_minimize(menu)
    #end

    # window/zoom
    def on_zoom(menu)
    end
end

WretchDL.new.start
