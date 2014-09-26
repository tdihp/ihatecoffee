Symbolizer = require './base'

util = require '../util'
{CapStitchRound, CapStitchButt, CapStitchSquare, JoinStitchMiter, JoinStitchRound, JoinStitchBevel} = require '../stitch'
{PI_X_2, p2pAngle, vecAngle, normRadian, EasyBuffer, initProgram} = util

fs = require 'fs'


class LineSymbolizer extends Symbolizer
    styleSize: 8
    maxIntensity: 3
    directionLimit: 65536
    edges: 20
    constructor: (gl) ->
        super(gl)
        gl = @gl
        vertexShader = """
        #define STYLE_SIZE #{@styleSize}
        #define DIRECTION_RAD #{PI_X_2 / @directionLimit}
        #define INTENSITY_MULTIPLY float(#{(@maxIntensity - 1.0)})
        #{fs.readFileSync(__dirname + '/shaders/line.vertex.glsl', 'utf8')}
        """
        #vertexShader = fs.readFileSync(__dirname + '/shaders/line.vertex.glsl', 'utf8')
        fragmentShader = fs.readFileSync(__dirname + '/shaders/line.fragment.glsl', 'utf8')
        program = initProgram(gl, vertexShader, fragmentShader)
        @program = program

        @a_position = gl.getAttribLocation(program, 'a_position')
        @a_direction = gl.getAttribLocation(program, 'a_direction')
        @a_stroke = gl.getAttribLocation(program, 'a_stroke')
        @a_intensity = gl.getAttribLocation(program, 'a_intensity')

        @u_resolution = gl.getUniformLocation(program, 'u_resolution')
        @u_palette = gl.getUniformLocation(program, 'u_palette')
        @u_widths = gl.getUniformLocation(program, 'u_widths')

    enter: (context) ->
        # various configurations before draw
        super()
        # setup program
        gl = @gl
        gl.useProgram(@program)
        #gl.disable(gl.BLEND)
        gl.disable(gl.DEPTH_TEST)
        # set resolution from context
        {width, height} = context.resolution
        gl.uniform2f(@u_resolution, width, height)

    exit: () ->
        super()

    doDraw: (bucket) ->
        gl = @gl
        
        gl.clearColor(0.8, 0.8, 0.8, 1)
        gl.clearDepth(1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
        
        bucket.bindIt()
        #console.log "LineSymbolizer drawing #{bucket.size()}"

        gl.drawElements(gl.TRIANGLE_STRIP, bucket.size(), gl.UNSIGNED_SHORT, 0)

    newBucket: () ->
        # create new data bucket(stitcher) to be fed
        return new LineBucket(@)

    newStyle: (styleConfig={}) ->
        # if config not given, return a default style for peace
        return new LineStyle(@, styleConfig.palette, styleConfig.widths)

    _setStyle: (palette, widths) ->
        flatPalette = []
        for c in palette
            flatPalette = flatPalette.concat c
        #console.log("update style to palette: #{palette}, widths: #{widths}")
        gl.uniform4fv(@u_palette, flatPalette)
        gl.uniform1fv(@u_widths, widths)


class LineStyle
    constructor: (@symbolizer, @palette, @widths) ->
        styleSize = @symbolizer.styleSize
        if not @palette
            @palette = ([0, 0, 0, 1] for i in [0...styleSize])
        if not @widths
            @widths = (1 for i in [0...styleSize])

    bindIt: () ->
        @symbolizer._setStyle(@palette, @widths)


class LineBucket
    constructor: (@symbolizer) ->
        @dirty=true
        @stitcher = new LinerStitch(@symbolizer.edges,
                                    @symbolizer.maxIntensity,
                                    @symbolizer.directionLimit
                                    )
        @arrayBuffer = @symbolizer.gl.createBuffer()
        @elementArrayBuffer = @symbolizer.gl.createBuffer()

    feed: (symbol) ->
        @dirty=true
        console.log "LineBucket feeding #{[symbol.line, symbol.stroke, symbol.lineCap, symbol.lineJoin]}"
        return @stitcher.addLine(symbol.line, symbol.stroke, symbol.lineCap, symbol.lineJoin)

    # XXX: use bindIt for prestore data
    bindIt: () ->
        gl = @symbolizer.gl
        if @dirty
            @freeze()
        else
            gl.bindBuffer(gl.ARRAY_BUFFER, @arrayBuffer)
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, @elementArrayBuffer)
        @setVertexAttribLayout()

    freeze: () ->
        # store into gl
        gl = @symbolizer.gl
        gl.bindBuffer(gl.ARRAY_BUFFER, @arrayBuffer)
        gl.bufferData(gl.ARRAY_BUFFER, @stitcher.pointBuffer.buffer, gl.STATIC_DRAW)
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, @elementArrayBuffer)
        console.log "freezing elements #{@stitcher.elements}"
        element_array = new Uint16Array(@stitcher.elements)
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, element_array, gl.STATIC_DRAW)
        @dirty = false

    setVertexAttribLayout: () ->
        # the layout of the buffer is always assumed so.
        gl = @symbolizer.gl
        {a_position, a_direction, a_stroke, a_intensity} = @symbolizer
        gl.enableVertexAttribArray(a_position)
        gl.enableVertexAttribArray(a_direction)
        gl.enableVertexAttribArray(a_stroke)
        gl.enableVertexAttribArray(a_intensity)
        gl.vertexAttribPointer(a_position, 2, gl.UNSIGNED_SHORT, false, 8, 0)
        gl.vertexAttribPointer(a_direction, 1, gl.UNSIGNED_SHORT, false, 8, 4)
        gl.vertexAttribPointer(a_stroke, 1, gl.UNSIGNED_BYTE, false, 8, 6)
        gl.vertexAttribPointer(a_intensity, 1, gl.UNSIGNED_BYTE, false, 8, 7)

    size: () ->
        return @stitcher.elements.length


class LinerStitch
    ###
    join diagram:
        -> dir0   s0
    p0 o--------+ p1
             s1 |
       2theta   | | dir1
                |\/
                |
                o p2
    ###

    constructor: (@edges, @maxIntensity, @directionLimit)->
        @pointBuffer = new EasyBuffer(8)
        @elements = []
        @capStitches =
            butt: new CapStitchButt()
            round: new CapStitchRound(@edges)
            square: new CapStitchSquare()
        @joinStitches =
            miter: new JoinStitchMiter()
            round: new JoinStitchRound(@edges)
            bevel: new JoinStitchBevel()

    packVertex: (x, y, pointInfo, stroke) ->
        # return id of the vertex
        ### About packing
        Planned:
            point array: x y direction intensity side bend stroke   (8 bytes)
                         H H H         B         B:1  B:1  B:6

            HH  x, y      -- the old fashioned location
            H   direction -- the way this point will shift
            B   intensity -- how hard the point will shift, also used to make linesofar
            B:1 side      -- start-left or start-right
            B:1 bend      -- inner or outer, for dash to work properly
        Actual:
            HH  x, y      -- the old fashioned location
            H   direction -- the way this point will shift
            B   stroke    -- direct to an uniform array
            B   intensity -- how hard the point will shift

            elements:
                - ushort triangles: 6 * triangles
                - ushort triangle_strip: (triangles + 2) * 2 but how to fan
                  it will work but it's hard, maybe not worth it
                  
            now we use TRIANGLES elements for simplicity
        ###
        # maxIntensity=5 means integer intensity is mapped from 0-255 -> 1.0-5.0
        direction = normRadian(pointInfo.dir)
        intensity = pointInfo.intensity or 1
        if intensity < 1
            intensity = 1
        else if intensity > @maxIntensity
            # clipped, this will not be right, but working.
            intensity = @maxIntensity
        dv = @pointBuffer.getbuf()
        dv.setUint16(0, x, true)
        dv.setUint16(2, y, true)
        dv.setUint16(4, Math.floor(direction * @directionLimit / PI_X_2), true)
        dv.setUint8(6, stroke)
        dv.setUint8(7, Math.floor((intensity - 1) * 255 / (@maxIntensity - 1)))
        @pointBuffer.incr()
        console.log("packed: #{x}, #{y}, #{Math.floor(direction * @directionLimit / PI_X_2)}, #{stroke}, #{Math.floor((intensity - 1) * 255 / (@maxIntensity - 1))}")

    addLine: (line, stroke, lineCap='butt', lineJoin='miter') ->
        if line.length < 2
            return false
        results = []

        [dir0, result] = @_open(lineCap, line[0], line[1])
        results.push(result)
        for i in [1...line.length-1]
            [dir0, result] = @_join(lineJoin, dir0, line[i], line[i + 1])
            results.push(result)
        result = @_close(lineCap, dir0)
        results.push(result)

        elementOffset = @pointBuffer.itemCnt
        lineElementCnt = ((result.line0.length + result.line1.length) for result in results).reduce (x, y) -> x + y
        if @elements.length + lineElementCnt + 2 > 65535
            console.log('element buffer overflow')
            return true

        # connect with the last line strip
        if @elements.length > 0
            @elements.push(@elements[@elements.length - 1])
            @elements.push(results[0].line0[0] + elementOffset)

        inLineOffset = 0
        for result, i in results
            line1 = result.line1
            for index0, j in result.line0
                index1 = line1[j]
                @elements.push(index0 + elementOffset + inLineOffset)
                @elements.push(index1 + elementOffset + inLineOffset)
            inLineOffset += results[i].points.length

        for result, i in results
            [x, y] = line[i]
            for pointInfo in result.points
                #console.log("@packVertex(x, y, pointInfo, stroke): #{x}, #{y}, #{JSON.stringify pointInfo}, #{stroke}")
                @packVertex(x, y, pointInfo, stroke)
        return false

    _open: (lineCap, p0, p1) ->
        # return dir0, result
        dir0 = p2pAngle(p0, p1)
        return [dir0, @capStitches[lineCap].open(dir0)]

    _close: (lineCap, dir0) ->
        # return result
        return @capStitches[lineCap].close(dir0)

    _join: (lineJoin, dir0, p1, p2) ->
        # return dir1, result
        dir1 = p2pAngle(p1, p2)
        return [dir1, @joinStitches[lineJoin].join(dir0, dir1)]


module.exports = LineSymbolizer