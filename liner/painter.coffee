{LineSymbolizer, DashlineSymbolizer} = require './symbolizer/exports.coffee'


class Painter
    ### 
        feed objects to symbolizers
        maintain status of draw order
        call symbolizers to draw things
        
        Note that there is only 1 painter object!
        
        # XXX: depth culling. now it's just normal mode 
    ###
    constructor: (@gl) ->
        ###
            init all symbolizers, and their style configurations
            some styles require preparation, because of extra textures
            so must initialized first
        ###
        @symbolizers =
            line: new LineSymbolizer(@gl)
            dashline: new DashlineSymbolizer(@gl)

        @clear()

    feed: (symbol) ->
        ###
            decide what to do with the symbol
            NOTE: we STRICTLY preserve draw order, and it's painter's job to
            do so
        ###
        # console.log "feeding symbol #{JSON.stringify symbol}"
        symbolizerName = symbol.type or 'line'
        styleName = symbol.style or 'default'
        symbolizer = @symbolizers[symbolizerName]

        if symbolizerName != @currentSymbolizer or styleName != @currentStyle
            slotID = symbolizer.newSlot()
            @drawSequence.push({styleName: styleName, symbolizerName, slotID})
            @currentSymbolizer = symbolizerName
            @currentStyle = styleName
        else
            slotID = @drawSequence[@drawSequence.length - 1].slotID

        symbolizer.feed(slotID, symbol)

    flush: () ->
        ###
            call when all fed, generally used to bind buffers early
            XXX: maybe initialize style should be here? not for now though
        ###

    draw: (context) ->
        ###
            draw all that's 
        ###
        gl.clearColor(0.8, 0.8, 0.8, 1)
        gl.clearDepth(1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        gl.enable(gl.BLEND)
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

        gl.disable(gl.DEPTH_TEST)

        symbolizerName = null
        for config in @drawSequence
            if config.symbolizerName != symbolizerName
                if symbolizerName
                    @symbolizers[symbolizerName].exit()
                symbolizerName = config.symbolizerName
                # console.log "using symbolizer #{symbolizerName}"
                @symbolizers[symbolizerName].enter(context)

            @symbolizers[symbolizerName].draw(config.slotID, config.styleName)

        if symbolizerName
            @symbolizers[symbolizerName].exit()

    clear: () ->
        ###
            remove all symbols
        ###
        @drawSequence = []
        @currentSymbolizer = null
        @currentStyle = null


module.exports = Painter
