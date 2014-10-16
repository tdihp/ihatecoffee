# this draws webgl lines
window.liner = {
}

Painter = require './liner/painter'
{rgb2f, darken} = require './liner/util'


liner.createPainter = (gl) ->
    painter = new Painter(gl)
    palette = []
    widths = []

    # update style
    palette[0] = rgb2f(248, 242, 218)
    widths[0] = 5

    palette[1] = darken(palette[0], 0.6)
    widths[1] = 6

    palette[2] = rgb2f(199, 175, 189)
    widths[2] = 4.5

    palette[3] = darken(palette[2], 0.6)
    widths[3] = 5.5

    palette[4] = rgb2f(221, 236, 239)
    widths[4] = 3

    palette[5] = darken(palette[4], 0.6)
    widths[5] = 4

    palette[6] = darken(rgb2f(200, 200, 200), 0.2)
    widths[6] = 0.5

    #palette[7] = darken(palette[6], 0.2)
    palette[7] = [0,0,0,0]
    widths[7] = 0

    painter.symbolizers.line.updateStyle('default',
        {palette, widths}
    )

    # dash style
    dashes = ([i*8, i*4] for i in [1..8])
    widths = (i * 2 for i in [1..8])
    palette = ([i/8, i/8, i/8, 1] for i in [1..8])
    palette[0] = [0.4, 0.4, 0.4, 1]
    widths[0] = 4
    dashes[0] = [1.5, 8]
    painter.symbolizers.dashline.updateStyle('default',
        {palette, widths, dashes}
    )

    points = [[100, 100], [300, 100], [250, 300]]#, [400, 300], [600, 200], [700, 250]]
    
    #painter.feed({type: 'dashline', line: points, stroke: 0, lineJoin: 'bevel'})
    return painter


liner.addLines = (painter, lines)->
    for line in lines
        painter.feed(line)
