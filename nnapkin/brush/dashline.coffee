{BrushHelper} = require './base'
{LinePalette, LineConverter} = require './line'

EPS = 1e-10


linearInterpolation = (x, y0, y1, x0, x1) ->
    if (x1 - x) < EPS
        return y1
    else if (x - x0) < EPS
        return y0
    return (y1 - y0) * (x - x0) / (x1 - x0)


makeDash = (dasharray, setAlpha, texWidth=256, aaWidth=1) ->
    ###return dashCycle and pixels
    aaWidth in pixel for antialias
    setAlpha is (i, v) to set alpha value for specific pixel
    ###
    if dasharray.length < 2
        throw "invalid dasharray #{dasharray}"

    if dasharray.length % 2
        dasharray = [dasharray..., dasharray...]

    dashCycle = dasharray.reduce (t, s)-> t + s
    blendLength = (aaWidth / dashCycle * texWidth)

    sofar = -blendLength / 2
    interpolateArray = []
    for l, i in dasharray
        v = ((i + 1) % 2) * 255
        interpolateArray.push {v, p: sofar + blendLength}
        sofar += l / dashCycle * texWidth
        interpolateArray.push {v, p: sofar}
    # add final interpolation
    interpolateArray.push({v: 0, p: sofar + blendLength})
    
    rightIndex = 0
    left = -blendLength / 2
    lv = 0
    for pix, i in [0...texWidth]
        pix += 0.5
        right = interpolateArray[rightIndex].p
        rv = interpolateArray[rightIndex].v
        while right < pix
            left = right
            lv = rv
            rightIndex += 1
            right = interpolateArray[rightIndex].p
            rv = interpolateArray[rightIndex].v

        setAlpha(i, Math.round(linearInterpolation(pix, lv, rv, left, right)))

    return dashCycle


class DashlinePalette extends LinePalette
    constructor: (brush)->
        super(brush)
        gl = @brush.gl
        # create texture object
        @textureWidth = @symbolizer.textureWidth
        @textureHeight = @symbolizer.textureHeight

    bindIt: () ->
        if not @frozen?
            @freeze()
        gl = @brush.gl
        gl.uniform4fv(@brush.u_palette, @frozen.palette)
        gl.uniform1fv(@brush.u_widths, @frozen.widths)
        gl.activeTexture(gl.TEXTURE0)
        gl.bindTexture(gl.TEXTURE_2D, @frozen.texture)
        gl.uniform1i(@brush.u_sampler, 0)

    freeze: () ->
        palette = []
        widths = []
        imageData = ArrayBuffer(@textureWidth * textureHeight * 4)

        for [color, width, dasharray], i in elements
            palette = [palette..., rgb2f(color)...]
            widths.push width
            array = Uint8Array(imageData, i * @textureWidth * 4, @textureWidth * 4)
            setAlpha = (index, value) ->
                cindex = index * 4
                array[cindex++] = 255
                array[cindex++] = 255
                array[cindex++] = 255
                array[cindex] = value

            makeDash(dasharray, setAlpha, @textureWidth)

        gl = @brush.gl
        texture = gl.createTexture()
        gl.activeTexture(gl.TEXTURE0)
        gl.bindTexture(gl.TEXTURE_2D, texture)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @textureWidth, @textureWidth, 0,
            gl.RGBA, gl.UNSIGNED_BYTE, imageData)
        @frozen = {texture, palette, widths}


class DashlineBrush extends BrushHelper
    converter: new LineConverter()
    attribMap:
        a_position: (gl, attrib) -> gl.vertexAttribPointer(attrib, 2, gl.SHORT, false, 16, 0)
        a_direction: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_SHORT, false, 16, 4)
        a_depth: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_BYTE, false, 16, 6)
        a_intensity: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_BYTE, true, 16, 7)
        a_palette_index: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.UNSIGNED_BYTE, true, 16, 8)
        a_line_sofar: (gl, attrib) -> gl.vertexAttribPointer(attrib, 1, gl.FLOAT, true, 16, 12)

    constructor: (gl, @paletteSize=8, @directionLimit=65536, @maxIntensity=3, @textureWidth=256, @textureHeight=64) ->
        vertexShader = """
        #define PALETTE_SIZE #{@paletteSize}
        #define DIRECTION_RAD #{PI_X_2 / @directionLimit}
        #define INTENSITY_MULTIPLY float(#{(@maxIntensity - 1.0)})
        #
        #{fs.readFileSync(__dirname + '/shaders/line.include.vertex.glsl', 'utf8')}
        #{fs.readFileSync(__dirname + '/shaders/dashline.vertex.glsl', 'utf8')}
        """

        fragmentShader = fs.readFileSync(__dirname + '/shaders/dashline.fragment.glsl', 'utf8')

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
        @u_dash_cycles = gl.getUniformLocation(program, 'u_dash_cycles')
        @u_sampler = gl.getUniformLocation(program, 'u_sampler')

    packer: (v, dataView) =>
        [x, y] = v
        {dir, intensity, paletteIndex, lineSofar} = v
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
        dataView.setFloat32(12, lineSofar)

    newAssembler: () ->
        return new Assembler(16, @packer, @converter.func, true, @gl, @gl.TRIANGLE_STRIP, @attribMap)

module.exports ={
    DashlineBrush
}