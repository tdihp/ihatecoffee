Array::merge = (other) -> Array::push.apply @, other

PI_X_2 = Math.PI * 2

p2pAngle = (p0, p1) ->
    # get the angle to y axis
    [p0x, p0y] = p0
    [p1x, p1y] = p1
    dirx = p1x - p0x
    diry = p1y - p0y
    return vecAngle(dirx, diry)


vecAngle = (x, y) ->
    distance = Math.sqrt(x * x + y * y)
    cosv = y / distance
    theta = Math.acos cosv
    if x < 0
        #theta += Math.PI
        theta = PI_X_2 - theta
    return theta


pacman = (beginAngle, stopAngle, edges=16) ->
    # angles are [0, 2pi) values, evaluated cw
    
    # yield a list of angles in the middle, assume that a perfect circle is
    # contains `edges` mount of edges.
    beginAngle = normRadian(beginAngle)
    stopAngle = normRadian(stopAngle)

    angleUnit = PI_X_2 / edges
    
    beginUnit = Math.floor(beginAngle / angleUnit)
    stopUnit = Math.ceil(stopAngle / angleUnit)

    # XXX: what happens if begin unit or stop unit is exact? will be duplicate!
    result = [beginAngle, stopAngle]
    if beginUnit < stopUnit
        r = [beginUnit..stopUnit][1...-1]
    else
        r = [beginUnit...edges].concat([0..stopUnit])[1...-1]
    result[1...1] = (normRadian(u * angleUnit) for u in r)
    return result


normRadian = (rad)->
   
    rad = rad % (PI_X_2)
    if rad < 0
        rad += PI_X_2
    return rad


angleDiff = (angle1, angle2) ->
    ###
    return degree of angle2 - angle1
    value range is (-pi, pi]
    ###
    angle1 = normRadian(angle1)
    angle2 = normRadian(angle2)
    d = angle2 - angle1
    if d > Math.PI
        d -= PI_X_2
    
    if d <= -Math.PI
        d += PI_X_2

    return d


# javascript buffers stacked for lining
class EasyBuffer
    constructor: (@bytes, @size=65536) ->
        @buffer = new ArrayBuffer(@size * @bytes)
        @offset = 0
        @itemCnt = 0

    getbuf: () ->
        if @offset >= @size
            throw 'buffer overflow'
        return new DataView(@buffer, @offset, @bytes)

    incr: () ->
        @itemCnt += 1
        @offset += @bytes


rgb2f = ([r,g,b,a]) ->
    a = a? or 0
    return [r / 255, g / 255, b / 255, 1 - (a / 255)]


darken = ([r, g, b, a], ratio) ->
    a = a? or 0
    return [r * ratio, g * ratio, b * ratio, a]


module.exports =
    PI_X_2
    p2pAngle
    vecAngle
    pacman
    normRadian
    angleDiff
    EasyBuffer
    rgb2f
    darken
