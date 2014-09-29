Symbolizer = require './base'

util = require '../util'
{CapStitchRound, CapStitchButt, CapStitchSquare,
 JoinStitchMiter, JoinStitchRound, JoinStitchBevel,
 Stitcher} = require '../stitch'
{PI_X_2, normRadian, EasyBuffer, initProgram} = util

fs = require 'fs'


class DashlineSymbolizer extends Symbolizer
    styleSize: 8
    maxIntensity: 3
    directionLimit: 65536
    edges: 20
    texWidth: 256
    texHeight: 64  # minimum tex width / height for opengl ES
    constructor: (gl) ->
        super(gl)
        gl = @gl
        vertexShader = """
        #define STYLE_SIZE #{@styleSize}
        #define DIRECTION_RAD #{PI_X_2 / @directionLimit}
        #define INTENSITY_MULTIPLY float(#{(@maxIntensity - 1.0)})
        #define TEXTURE_HEIGHT #{@texHeight}
        #{fs.readFileSync(__dirname + '/shaders/dashline.vertex.glsl', 'utf8')}
        """
        fragmentShader = fs.readFileSync(__dirname + '/shaders/dashline.fragment.glsl', 'utf8')
        program = initProgram(gl, vertexShader, fragmentShader)
        @program = program

        @a_position = gl.getAttribLocation(program, 'a_position')
        @a_direction = gl.getAttribLocation(program, 'a_direction')
        @a_stroke = gl.getAttribLocation(program, 'a_stroke')
        @a_intensity = gl.getAttribLocation(program, 'a_intensity')
        # @a_side = gl.getAttribLocation(program, 'a_side')
        @a_line_sofar = gl.getAttribLocation(program, 'a_line_sofar')

        @u_resolution = gl.getUniformLocation(program, 'u_resolution')
        @u_palette = gl.getUniformLocation(program, 'u_palette')
        @u_widths = gl.getUniformLocation(program, 'u_widths')
        @u_dash_cycle = gl.getUniformLocation(program, 'u_dash_cycle')
        @u_sampler = gl.getUniformLocation(program, 'u_sampler')

    enter: (context) ->
        # various configurations before draw
        super()
        # setup program
        gl = @gl
        gl.useProgram(@program)

        # set resolution from context
        {width, height} = context.resolution
        gl.uniform2f(@u_resolution, width, height)

    exit: () ->
        super()

    doDraw: (bucket) ->
        gl = @gl
        bucket.bindIt()
        #console.log "LineSymbolizer drawing #{bucket.size()}"
        gl.drawElements(gl.TRIANGLE_STRIP, bucket.size(), gl.UNSIGNED_SHORT, 0)

    newBucket: () ->
        # create new data bucket(stitcher) to be fed
        return new DashlineBucket(@)

    newStyle: (styleConfig={}) ->
        # if config not given, return a default style for peace
        return new DashlineStyle(@, styleConfig.palette, styleConfig.widths, styleConfig.dashes)

    _setStyle: (palette, widths, dashCycles, texture) ->
        flatPalette = []
        for c in palette
            flatPalette = flatPalette.concat c
        #console.log("update style to palette: #{palette}, widths: #{widths}")
        gl.uniform4fv(@u_palette, flatPalette)
        gl.uniform1fv(@u_widths, widths)
        gl.uniform1fv(@u_dash_cycle, dashCycles)

        gl.activeTexture(gl.TEXTURE0)
        gl.bindTexture(gl.TEXTURE_2D, texture)
        gl.uniform1i(@u_sampler, 0)


makedash = (dasharray, buffer, texWidth=256, aaWidth=1) ->
    ###return dashCycle and pixels
    aaWidth in pixel for antialias
    ###
    if dasharray.length != 2
        throw "invalid dasharray #{dasharray}"

    dashCycle = dasharray.reduce (t, s)-> t + s

    [dashPix, gapPix] = dasharray
    dashPix -= aaWidth
    gapPix -= aaWidth

    dashLength = Math.round(dashPix / dashCycle * texWidth)
    blendLength = Math.round(aaWidth / dashCycle * texWidth)
    gapLength = texWidth - dashLength - (blendLength * 2)

    blendStep = 255 / (blendLength + 2)

    i = 0
    for j in [0...dashLength]
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = 255
    
    # blendout
    alpha = 255 - blendStep
    for j in [0...blendLength]
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = Math.round(alpha)
        alpha -= blendStep

    for j in [0...gapLength]
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = 0

    # blend in
    alpha = blendStep
    for j in [0...gapLength]
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = 255
        buffer[i++] = Math.round(alpha)
        alpha += blendStep

    return dashCycle


class DashlineStyle
    constructor: (@symbolizer, @palette, @widths, @dashes) ->
        console.log "constructing dashline style with dashes #{@dashes}"
        styleSize = @symbolizer.styleSize
        texWidth = @symbolizer.texWidth
        texHeight = @symbolizer.texHeight
        if not @palette
            @palette = ([0, 0, 0, 1] for i in [0...styleSize])
        if not @widths
            @widths = (1 for i in [0...styleSize])
        if not @dashes
            @dashes = ([1, 1] for i in [0...styleSize])

        image = new Uint8Array(texWidth * texHeight * 4)
        for i in [0...image.length]
            image[i] = 255
            
        @dashCycles = []
        for dash, i in @dashes
            buffer = new Uint8Array(image.buffer, i * texWidth * 4, texWidth * 4)
            @dashCycles.push makedash(dash, buffer, texWidth)

        gl = @symbolizer.gl
        @texture = gl.createTexture()

        gl.activeTexture(gl.TEXTURE0)
        gl.bindTexture(gl.TEXTURE_2D, @texture)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, texWidth, texHeight, 0,
            gl.RGBA, gl.UNSIGNED_BYTE, image)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

    bindIt: () ->
        @symbolizer._setStyle(@palette, @widths, @dashCycles, @texture)


class DashlineBucket
    constructor: (@symbolizer) ->
        @dirty=true
        @stitcher = new DashlineStitcher(@symbolizer.edges,
            @symbolizer.maxIntensity,
            @symbolizer.directionLimit
        )
        @arrayBuffer = @symbolizer.gl.createBuffer()
        @elementArrayBuffer = @symbolizer.gl.createBuffer()

    feed: (symbol) ->
        @dirty=true
        #console.log "LineBucket feeding #{[symbol.line, symbol.stroke, symbol.lineCap, symbol.lineJoin]}"
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
        #console.log "freezing elements #{@stitcher.elements}"
        element_array = new Uint16Array(@stitcher.elements)
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, element_array, gl.STATIC_DRAW)
        @dirty = false

    setVertexAttribLayout: () ->
        # the layout of the buffer is always assumed so.
        gl = @symbolizer.gl
        {a_position, a_direction, a_stroke, a_intensity, a_line_sofar} = @symbolizer
        gl.enableVertexAttribArray(a_position)
        gl.enableVertexAttribArray(a_direction)
        gl.enableVertexAttribArray(a_stroke)
        gl.enableVertexAttribArray(a_intensity)
        gl.enableVertexAttribArray(a_line_sofar)
        gl.vertexAttribPointer(a_position, 2, gl.UNSIGNED_SHORT, false, 12, 0)
        gl.vertexAttribPointer(a_direction, 1, gl.UNSIGNED_SHORT, false, 12, 4)
        gl.vertexAttribPointer(a_stroke, 1, gl.UNSIGNED_BYTE, false, 12, 6)
        gl.vertexAttribPointer(a_intensity, 1, gl.UNSIGNED_BYTE, true, 12, 7)
        gl.vertexAttribPointer(a_line_sofar, 1, gl.FLOAT, true, 12, 8)

    size: () ->
        return @stitcher.elements.length


class DashlineStitcher extends Stitcher
    constructor: (@edges, @maxIntensity, @directionLimit)->
        @pointBuffer = new EasyBuffer(12)
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
            HH   x, y      -- the old fashioned location
            H    direction -- the way this point will shift
            B    stroke    -- direct to an uniform array
            B    intensity -- how hard the point will shift
            f    line_so_far
        ###
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
        dv.setFloat32(8, pointInfo.lineSoFar, true)
        @pointBuffer.incr()
        console.log("packed lineSoFar: #{pointInfo.lineSoFar}")
        # console.log("packed: #{x}, #{y}, #{Math.floor(direction * @directionLimit / PI_X_2)}, #{stroke}, #{Math.floor((intensity - 1) * 255 / (@maxIntensity - 1))}")

    addLine: (line, stroke, lineCap='butt', lineJoin='miter') ->
        lineSoFar = 0
        line[0].lineSoFar = lineSoFar
        [lastX, lastY] = line[0]
        for p in line[1..]
            [x, y] = p
            lineSoFar += Math.sqrt((x - lastX) ** 2 + (y - lastY) ** 2)
            p.lineSoFar = lineSoFar
            lastX = x
            lastY = y

        stitches = @stitchLine(line, lineCap, lineJoin)
        if not stitches
            return false

        {vertices, elements} = stitches

        elementOffset = @pointBuffer.itemCnt
        if elementOffset + vertices.length > 65535
            console.log('element buffer overflow')
            return true

        # connect with the last line strip
        if @elements.length > 0
            @elements.push(@elements[@elements.length - 1])
            @elements.push(elements[0] + elementOffset)

        for element in elements
            @elements.push(element + elementOffset)

        for vertex in vertices
            [x, y] = vertex
            #console.log("@packVertex(x, y, pointInfo, stroke): #{x}, #{y}, #{JSON.stringify pointInfo}, #{stroke}")
            @packVertex(x, y, vertex, stroke)

        return false


module.exports = DashlineSymbolizer