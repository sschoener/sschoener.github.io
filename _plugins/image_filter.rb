module Jekyll
    module ImageWrapperFilter
        def wrap_images(input)
            input.gsub(/<img(.*?)>/, '<p align="middle"><img\1></p>')
        end
    end
end

Liquid::Template.register_filter(Jekyll::ImageWrapperFilter)
