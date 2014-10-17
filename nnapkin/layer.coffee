### the same concept as in Mapnik


###

class Layer
    constructor: (@name, @styles) ->
    
    prepare: (areas) ->
        ### hint that those areas are to be drawn, prepare them
        ###
    drawOpaque: (areas) ->
        throw "not implemented!"
    drawBlend: (areas) ->
        throw "not implemented!"


class TileLayer
    constructor: (@name, styles) ->
        @rstyles = (style for style in styles by -1)

    makeInstructions: (features, brushes) ->
        ###this is the magic of the entire process idea
        ###
        currentDepth = 0
        # reversed
        features = (feature for feature in features by -1)
        
        opaque = {}  # brushName: instruction
        opaqueAssemblers = {}  # brushName: assembler
        blending = false
        blend = [] # {brushName, instruction}
        blendStack = []
        blendBrushName = null
        blendAssembler = null
        
        for feature in features
            for {rule, symbolizer} in @rstyles
                if not rule(feature.properties)
                    continue
                brushName = symbolizer.brushName
                
                if symbolizer.opaque
                    if blending and blendBrushName # actually blending
                        # flush last blend stack
                        for {geometry, renderArgs} in blendStack
                            blendAssembler.feed(geometry, currentDepth, renderArgs)
                        currentDepth++
                        blendStack = []

                    assembler = opaqueAssemblers[brushName]
                    if not assembler
                        assembler = brushes[brushName].newAssembler()
                        opaqueAssemblers[brushName] = assembler
                    assembler.feed(feature.geometry, symbolizer.renderArgs)
                else
                    # blend
                    if blendBrushName != brushName
                        if blendAssembler
                            # flush last blend stack
                            for {geometry, renderArgs} in blendStack
                                blendAssembler.feed(geometry, currentDepth, renderArgs)
                            # freeze last assembler, for blend brush changed
                            instruction = blendAssembler.freeze()
                            blend.push {brushName: blendBrushName, instruction}
                        blendStack = []
                        blendAssembler = brushes[brushName].newAssembler()
                        blendBrushName = brushName
                    # last one is first to draw, as blend goes bottom up
                    blendStack.unshift {geometry: feature.geometry, renderArgs: symbolizer.renderArgs}

        # It will perform better if only one blendbrush used in layer,
        # for less brush switch will occur
        # the worst case is interleaved blend brush, AVOID!
        if blendBrushName  # final blend flush
            for {geometry, renderArgs} in blendStack
                blendAssembler.feed(geometry, currentDepth, renderArgs)
            instruction = blendAssembler.freeze()
            blend.push {brushName: blendBrushName, instruction}

        for brushName, assembler of opaqueAssemblers
            opaque[brushName] = assembler.freeze()

        # always add 1 to depth for gapping
        return {opaque, blend, depthUsed: currentDepth + 1}

