require 'rubygems' # disable this for a deployed application
require 'hotcocoa'



class WretchDL
    include HotCocoa

    def start
        application name: 'WretchDL' do |app|
            app.delegate = self
            window(size: [600, 500], center: true, title: 'WretchDL') do |win|
                win.will_close { exit }
                
            end
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
