### the same concept as in Mapnik


###

class Layer
    constructor: (@name, @styles) ->
    
    prepare: (areas) ->
        ### hint that those areas are to be drawn, prepare them
        ###
    drawOpaque: (areas) ->
        throw "not implemented!"
    drawBlend: (areas) ->
        throw "not implemented!"


class TileLayer extends Layer
    constructor: (name, styles, @dataSource) ->
        super(name, styles)

    instructionsOpaque: (tile) ->
        ### list all instructions to draw the metatile
        opaque instructions are ALWAYS unordered, to exploit chances to not
        change brush
        draw with:
            - BLEND off
            - depth test on
            - better to be front to back
        ###

    instructionsBlend: (tile) ->
        ### list all instructions to draw the metatile
        blend instructions are strictly ordered, and always draw with:
            - BLEND on
            - back to front
            - depth test on
            - do not write to depth buffer
        ###
        

