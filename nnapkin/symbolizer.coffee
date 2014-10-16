class Symbolizer
    ###
    a place holder in style, to describe how a data should be painted.
    generally means:
        - it refers to a brush by @brushName
        - it offers a @palletElement which will be registered
          to a brush, and add to brush's palette, note that this element have
          equal() to compare
        - it offers @renderArgs for assembler feed
        - it's either @opaque or not
        - note that @paletteIndex will be put into renderArgs
    ###


class LineSymbolizer extends Symbolizer
    brushName: 'line'
    constructor: (color=[255, 255, 255, 0], width=1, lineCap='butt', lineJoin='miter') ->
        @renderArgs = {lineCap, lineJoin}
        @palletElement = [color, width]  # have to use list to compare with JSON
        if color[3] != 0
            @opaque = false
        else
            @opaque = true


class DashlineSymbolizer extends Symbolizer
    brushName: 'dashline'
    constructor: (color=[255, 255, 255, 0], width=1, lineCap='butt', lineJoin='miter', dashArray=[1, 1]) ->
        @renderArgs = {lineCap, lineJoin}
        @palletElement = [color, width, dashArray]
        @opaque = false


module.exports =
    Line: (obj) ->
        {color, width, lineCap, lineJoin} = obj
        return new LineSymbolizer(color, width, lineCap, lineJoin)

    Dashline: (obj) ->
        {color, width, lineCap, lineJoin, dashArray} = obj
        return new DashlineSymbolizer(color, width, lineCap, lineJoin, dashArray)
