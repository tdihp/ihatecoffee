{BrushHelper} = require './base'

{CapStitchRound, CapStitchButt, CapStitchSquare,
 JoinStitchMiter, JoinStitchRound, JoinStitchBevel,
 Stitcher} = require '../stitch'

util = require '../util'
{PI_X_2, normRadian, rgb2f} = util

Assembler = require '../assembler'


shiftLine = (line, offset) ->
    [dx, dy] = offset
    return ([x + dx, y + dy] for [x, y] in line)


makeLineSofar = (line) ->
    lineSofar = 0
    line[0].lineSofar = lineSofar
    [lastX, lastY] = line[0]
    for p in line[1..]
        [x, y] = p
        lineSofar += Math.sqrt((x - lastX) ** 2 + (y - lastY) ** 2)
        p.lineSofar = lineSofar
        lastX = x
        lastY = y


class LineConverter extends Stitcher
    constructor: () ->
        @capStitches =
            butt: new CapStitchButt()
            round: new CapStitchRound(@edges)
            square: new CapStitchSquare()
        @joinStitches =
            miter: new JoinStitchMiter()
            round: new JoinStitchRound(@edges)
            bevel: new JoinStitchBevel()

    func: (geometry, renderArgs, offset) =>
        # XXX: make edges adaptable for each geom, with renderArgs
        line = shiftLine(geometry, offset)
        makeLineSofar(line)
        stitches = @stitchLine(line, lineCap, lineJoin)
        if stitches is null
            return null
        {vertices, elements} = stitches
        {paletteIndex, depth} = renderArgs
        vertices.map (v) ->
            v.paletteIndex = paletteIndex
            v.depth = depth
        return {array: vertices, elementArray: elements}


class LinePalette
    constructor: (@brush) ->
        @elements = []
        @frozen = null

    bindIt: () ->
        if not @frozen?
            @freeze()
        gl = @brush.gl
        gl.uniform4fv(@brush.u_palette, @frozen.palette)
        gl.uniform1fv(@brush.u_widths, @frozen.widths)

    register: (paletteElement) ->
        # use JSON for simplicity, but this MAY go wrong
        s = JSON.stringify(paletteElement)
        for v, i in @elements
            if JSON.stringify(v) == s
                return i
        @elements.push paletteElement
        if @elements.length > @brush.paletteSize
            throw "palette overflow!"
        return @elements.length - 1

    freeze: () ->
        palette = []
        widths = []
        for [color, width] in elements
            palette = [palette..., rgb2f(color)...]
            widths.push width

        @frozen = {palette, widths}


class LineBrush extends BrushHelper
    converter: new LineConverter()
    attribMap:
        a_position: (gl, attrib) -> gl.vertexAttribPointer(attrib, 2, gl.SHORT, false, 12, 0)
        a_direction: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_SHORT, false, 12, 4)
        a_depth: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_BYTE, false, 12, 6)
        a_intensity: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_BYTE, true, 12, 7)
        a_palette_index: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_BYTE, true, 12, 8)

    constructor: (gl, @paletteSize=8, @directionLimit=65536, @maxIntensity=3) ->
        vertexShader = """
        #define PALETTE_SIZE #{@paletteSize}
        #define DIRECTION_RAD #{PI_X_2 / @directionLimit}
        #define INTENSITY_MULTIPLY float(#{(@maxIntensity - 1.0)})
        #{fs.readFileSync(__dirname + '/shaders/line.include.vertex.glsl', 'utf8')}
        #{fs.readFileSync(__dirname + '/shaders/line.vertex.glsl', 'utf8')}
        """

        fragmentShader = fs.readFileSync(__dirname + '/shaders/line.fragment.glsl', 'utf8')

        super(gl, vertexShader, fragmentShader)

        program = @program

        @a_position = gl.getAttribLocation(program, 'a_position')
        @a_depth = gl.getAttribLocation(program, 'a_depth')
        @a_direction = gl.getAttribLocation(program, 'a_direction')
        @a_intensity = gl.getAttribLocation(program, 'a_intensity')
        @a_palette_index = gl.getAttribLocation(program, 'a_palette_index')
        @a_line_sofar = gl.getAttribLocation(program, 'a_line_sofar')

        @u_matrix = gl.getUniformLocation(program, 'u_matrix')
        @u_exmatrix = gl.getUniformLocation(program, 'u_exmatrix')
        @u_palette = gl.getUniformLocation(program, 'u_palette')
        @u_widths = gl.getUniformLocation(program, 'u_widths')
        @u_dash_cycle = gl.getUniformLocation(program, 'u_dash_cycle')
        @u_sampler = gl.getUniformLocation(program, 'u_sampler')

    packer: (v, dataView) =>
        [x, y] = v
        {dir, intensity, paletteIndex} = v
        intensity = intensity or 1
        direction = normRadian(dir)
        normDirection = Math.floor(direction * @directionLimit / PI_X_2)
        normIntensity =  Math.floor((intensity - 1) * 255 / (@maxIntensity - 1))
        dataView.setInt16(0, x, true)
        dataView.setInt16(2, y, true)
        dataView.setUint16(4, normDirection, true)
        dataView.setUint8(6, depth)
        dataView.setUint8(7, normIntensity)
        dataView.setUint8(8, paletteIndex)

    newAssembler: () ->
        return new Assembler(12, @packer, @converter.func, true, @gl, @gl.TRIANGLE_STRIP, @attribMap)

    newPalette: () ->
        

module.exports = {
    LineConverter
    LinePalette
    LineBrush
}