{ArrayBufferBucket, ElementArrayBufferBucket} = require './bucket'


class Assembler
    ### this is used to assemble buckets from geometrys ###
    sizeLimit:65536  # alrays control vertex size for simplicity
    constructor: (@vertexSize, @pack, @convert, @strip, @gl, @drawMode, @attribMap) ->
        ###
        pack: (vertex, dataView) ->
            to pack things into dataView
        convert: (geometry, renderArgs, offset) ->
            to convert geometry into array, return {array, elementArray}
            note that elementArray start from 0, related to array
            offset is point offset to add to each point
        if @strip, elements are stitched for strips
        ###
        @frozenBuckets = []
        @currentVertices = []
        @currentElements = null

    feed: (geometry, renderArgs, offset=[0, 0]) ->
        result = @convert(geometry, renderArgs, offset)
        if result is null
            return

        {array, elementArray} = result
        if @currentVertices.length + array.length > @sizeLimit
            @frozenBuckets.push(@makeBucket())
            @currentVertices = []
            @currentElements = null

        if elementArray?
            elementOffset = @currentVertices.length

            if @currentElements is null
                @currentElements = []
            if @strip
                if @currentElements.length > 0
                    @currentElements.push(@currentElements[@currentElements.length - 1])
                    @currentElements.push(elementArray[0] + elementOffset)
            elementArray.map (e) -> @currentElements.push(e + elementOffset)

        else if @strip
            # XXX: in this case arrayBuffer could be a little over sizeLimit
            # no need to be accurate huh?
            if @currentVertices.length > 0
                @currentVertices.push(@currentVertices[@currentVertices.length - 1])
                @currentVertices.push(array[0])
        @currentVertices = [@currentVertices..., array...]

    makeBucket: () ->
        arrayData = new ArrayBuffer(@vertexSize * @currentVertices.length)
        for v, i in @currentVertices
            dataView = new DataView(arrayData, @vertexSize * i, @vertexSize)
            @pack(v, dataView)

        if @currentElements is null
            return new ArrayBufferBucket(@gl, @drawMode, @attribMap,
                @currentVertices.length, arrayData)
        else
            if @currentVertices.length < 256
                elementData = new Uint8Array(@currentElements).buffer
                element8Bit = true
            else
                elementData = new Uint16Array(@currentElements).buffer
                element8Bit = false
            return new ElementArrayBufferBucket(@gl, @drawMode, @attribMap,
                @currentVertices.length, arrayData, elementData, element8Bit)

    freeze: () ->
        ### make and return instruction
        ###
        buckets = @frozenBuckets
        if @currentVertices.length > 0
            buckets = [buckets..., @makeBucket()]
        return buckets


module.exports = Assembler
