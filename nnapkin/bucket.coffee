###VBO abstraction
###

class BucketBase
    constructor: (@gl, @drawMode, @attribMap, @total, arrayData) ->
        gl = @gl
        @createBuffer()
        @bindBuffer()
        gl.bufferData(gl.ARRAY_BUFFER, arrayData, gl.STATIC_DRAW)

    applyAttribMapping: () ->
        gl = @gl
        for attribName, func of @attribMap
            attrib = brush[attribName]
            if attrib?
                func(gl, attrib)

    createBuffer: () ->
        gl = @gl
        @arrayBuffer = gl.createBuffer()

    bindBuffer: () ->
        gl = @gl
        gl.bindBuffer(gl.ARRAY_BUFFER, @arrayBuffer)

    draw: (brush, count=@total, offset=0) ->
        @bindBuffer()
        @applyAttribMapping()
        @_draw(brush, count, offset)


class ArrayBufferBucket extends BucketBase
    _draw: (brush, count, offset) ->
        gl = @gl
        @gl.drawArrays(@drawMode, offset, count)


class ElementArrayBufferBucket extends BucketBase
    constructor: (args..., elementData, @element8Bit=false)->
        super(args...)
        gl = @gl
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, elementData, gl.STATIC_DRAW)
        if @element8Bit
            @elementType=gl.UNSIGNED_BYTE
        else
            @elementType=gl.UNSIGNED_SHORT

    createBuffer: () ->
        super()
        gl = @gl
        @elementArrayBuffer = gl.createBuffer()

    bindBuffer: () ->
        super()
        gl = @gl
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, @elementArrayBuffer)

    _draw: (brush, drawMode, count, offset) ->
        gl = @gl
        if not @element8Bit
            offset *= 2

        gl.drawElements(@drawMode, count, @elementType, offset)


module.exports = {
    ArrayBufferBucket
    ElementArrayBufferBucket
}