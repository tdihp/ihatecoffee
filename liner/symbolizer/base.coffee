class Symbolizer
    ###
    symbolizer configures the style, and drawing of things
    the data is attached to it before any draw call
    
    NOTE it's not the equalavant of mapnik's symbolizer, though similar.
    
    NOTE the class interacts with several concepts:
        Symbolizer: subclasses
        Symbolizer.Bucket: data to bindIt/feed, symbolizer specific
    ###
    constructor: (@gl) ->
        @slots = []
        @styles = {}
        @currentStyleName = null
        @currentSlotID = null
        
        # always have a default style
        @updateStyle('default')

    enter: (context) ->
        # various configurations before draw

    exit: () ->
        # various configurations after draw
        @currentStyleName = null
        @currentSlotID = null

    draw: (slotID, styleName) ->
        # assume buffer already bound, uniforms already configured
        if not (@currentStyleName == styleName)
            @styles[styleName].bindIt()
            @currentStyleName = styleName

        for bucket in @slots[slotID]
            @doDraw(bucket)

        return

    doDraw: (bucket) ->
        throw 'not implemented!'

    feed: (slotID, symbol) ->
        # the symbol are to be fed into slot
        buckets = @slots[slotID]
        bucket = buckets[buckets.length - 1]
        if bucket.feed(symbol)  # if true, the bucket is full, try with new bucket
            bucket = @newBucket()
            buckets.push(bucket)
            if bucket.feed(symbol)
                throw "the symbol cant be fed at all!"

    newSlot: (styleName) ->
        i = @slots.length
        @slots.push([@newBucket()])
        return i

    newBucket: () ->
        # create new data bucket(stitcher) to be fed
        throw 'not implemented!'

    updateStyle: (styleName, styleConfig) ->
        @styles[styleName] = @newStyle(styleConfig)

    newStyle: (styleConfig) ->
        # if config not given, return a default style for peace
        throw 'not Implementd!'


module.exports = Symbolizer