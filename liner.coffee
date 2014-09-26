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

    palette[6] = rgb2f(72, 68, 82)
    widths[6] = 2

    palette[7] = rgb2f(255, 128, 128)
    widths[7] = 20

    painter.symbolizers.line.updateStyle('default',
        {palette, widths}
    )

    points = [[100, 100], [300, 100], [250, 300], [400, 300], [600, 200], [700, 250]]
    
    #painter.feed({type: 'line', line: points, stroke: 7})
    #painter.addLine(points, 2)
    #painter.addLine(points, 0, 'butt', 'bevel')
    #painter.addLine(points, 0, 'square', 'miter')
    #painter.addLine(points, 1, 'round', 'miter')
    #painter.addLine(points, 1, 'round', 'round')

    #painter.updateBuffer()
    return painter


liner.addLines = (painter, lines)->
    for line in lines
        #style = line.style
        painter.feed(line)
    #points = [[100, 100], [300, 100], [250, 300], [400, 300], [600, 200], [700, 250]]
    #points = [[100, 100], [300, 100]]
    #painter.addLine(points, 7)
    #painter.addLine(points, 7, 'butt', 'bevel')
    #painter.addLine(points, 0, 'square', 'miter')
    #painter.addLine(points, 7, 'square', 'bevel')
    #painter.addLine(points, 7, 'round', 'round')

    #painter.updateBuffer()