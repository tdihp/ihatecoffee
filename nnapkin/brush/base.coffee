{initProgram} = require '../glutil'


class Brush
    #vertexAttribs: []  # provide this to enable vertex attrib enable/disable

    constructor: (@gl) ->

    bindIt: () ->
        throw 'not implemented!'

    unBind: () ->
        throw 'not implemented!'

    setMatrix: (matrix) ->
        throw 'not implemented!'

    setExmatrix: (exmatrix) ->
        throw 'not implemented!'

    draw: (bucket) ->
        throw 'not implemented!'

    newAssembler: () ->
        ### create an assembler for this brush
        ###
        throw 'not implemented!'

    newPalette: () ->
        ### create an palette for this brush
        
        Palette is a concept have these things:
            register: (paletteElement) -> # return paletteIndex
            freeze: () -> # do anything to store state
                            (e.g. save texture, make buffer)
            bindIt: () -> # whatever thing to do to bind this palette
        ###
        throw 'not implemented!'

    usePalette: (palette) ->
        ### set current palette, do this BEFORE bind or will not have effect
        ###
        throw 'not implemented!'


class BrushHelper extends Brush
    ### helper for brush to deal with real world issues
    ###
    constructor: (gl, vertexShader, fragmentShader) ->
        super(gl)
        @program = initProgram(vertexShader, fragmentShader)
        @palette=null

    bindIt: (matrix, exmatrix) ->
        gl = @gl

        gl.useProgram(@program)

        # assume already cleaned by unBind, for it's simple
        for attr in @vertexAttribs
            gl.enableVertexAttribArray(attr)

        if @palette
            # no warning here, for brushes may have no palette at all
            @palette.bindIt()

    unBind: () ->
        gl = @gl

        for attr in @vertexAttribs
            gl.disableVertexAttribArray(attr)

    setMatrix: (matrix) ->
        # coordinate to screen, depth translation included
        @gl.uniformMatrix4fv(@u_matrix, false, matrix)

    setExmatrix: (exmatrix) ->
        # width to screen
        if @u_exmatrix
            gl.uniformMatrix4fv(@u_exmatrix, false, exmatrix)

    draw: (bucket) ->
        bucket.draw(@)

    usePalette: (palette) ->
        ### set current palette
        ###
        @palette = palette


module.exports = {
    Brush
    BrushHelper
}