###NNapkin

the API of such a rendering engine
###

class Screen
    updateTile: (srcName, tile, data) ->
        for i in @layerIndex[srcName]
            layer = @layers[i]
            layer.instructionsOpaque()
            layer.instructionsBlend()
        # XXX: update depth limit in metatiles
    purgeTile: (tile) ->
        # remove the tile from render
    tiles: () ->
        # list tiles in this screen


class NNapkin
    constructor: (layers, datasources) ->
        ###
            layers is a list of layer objects that should be rendered as
        painter's algo
        
            dataSources is the list of 
        ###
        
        # create brushes
        
    update: (z, bbox) ->
        # determine tiles, screen transform
        # exclude tile instructions not in tiles area
        # get not-available tiles from datasource (callback)
        
        
    onDataFetched: (srcName, tile, ) =>
        # make instructions and set to screen

    draw: () ->
        
        