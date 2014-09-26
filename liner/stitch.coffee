util = require './util'
{pacman, angleDiff} = util


class CapStitch
    open: (dir0) -> throw 'not implemented!'
    close: (dir0) -> throw 'not implemented!'


class JoinStitch
    join: (dir0, dir1) ->
        ###
        INPUT:
            dir0, dir1
        OUTPUT:
            points: newly created points to reference
                    not x, y, or z's, it's just direction, intensity, side(0/1)
                    for x, y should all be the same
            line0, line1: 2 parallel(ish) lines of id
        ###
        throw 'not implemented!'


class CapStitchRound extends CapStitch
    constructor: (@edges)-> super()

    open: (dir0) ->
        beginAngle = dir0 + Math.PI / 2
        endAngle = dir0 - Math.PI / 2
        fanDirs = pacman(beginAngle, endAngle, @edges)
        points = ({dir: d, side: 0} for d in fanDirs)
        points[0].side = 1
        line0 = [1...points.length]
        line1 = (0 for i in line0)
        return {points: points, line0: line0, line1: line1}

    close: (dir0) ->
        beginAngle = dir0 - Math.PI / 2
        endAngle = dir0 + Math.PI / 2
        fanDirs = pacman(beginAngle, endAngle, @edges)
        points = ({dir: d, side: 1} for d in fanDirs)
        points[0].side = 0
        line1 = [1...points.length].reverse()
        line0 = (0 for i in line1)
        return {points: points, line0: line0, line1: line1}


class CapStitchButt extends CapStitch
    open: (dir0) ->
        beginAngle = dir0 + Math.PI / 2
        endAngle = dir0 - Math.PI / 2
        points = [{dir: beginAngle, side: 1}, {dir: endAngle, side: 0}]
        line0 = [1]
        line1 = [0]
        return {points: points, line0: line0, line1: line1}

    close: (dir0) ->
        beginAngle = dir0 - Math.PI / 2
        endAngle = dir0 + Math.PI / 2
        points = [{dir: beginAngle, side: 0}, {dir: endAngle, side: 1}]
        line0 = [0]
        line1 = [1]
        return {points: points, line0: line0, line1: line1}


class CapStitchSquare extends CapStitch
    open: (dir0) ->
        beginAngle = dir0 + Math.PI * 3 / 4
        endAngle = dir0 - Math.PI * 3 / 4
        points = [{dir: beginAngle, side: 1, intensity: Math.sqrt(2)}, {dir: endAngle, side: 0, intensity: Math.sqrt(2)}]
        line0 = [1]
        line1 = [0]
        return {points: points, line0: line0, line1: line1}

    close: (dir0) ->
        beginAngle = dir0 - Math.PI * 1 / 4
        endAngle = dir0 + Math.PI * 1 / 4
        points = [{dir: beginAngle, side: 0, intensity: Math.sqrt(2)}, {dir: endAngle, side: 1, intensity: Math.sqrt(2)}]
        line0 = [0]
        line1 = [1]
        return {points: points, line0: line0, line1: line1}


class JoinStitchHelper extends JoinStitch
    join: (dir0, dir1) ->
        outerAngle = angleDiff(dir0, dir1)
        if outerAngle < 0
            cw = false
            theta = (Math.PI + outerAngle) / 2
        else
            cw = true
            theta = -(Math.PI - outerAngle) / 2

        axisDir = dir0 + theta + Math.PI
        intensity = Math.abs(1 / Math.sin(theta))  # used for fan axis only
        return @joinEasy(dir0, dir1, outerAngle, cw, theta, axisDir, intensity)

    joinEasy: (dir0, dir1, outerAngle, cw, theta, axisDir, intensity) ->
        throw 'not implemented!'
        
        
class JoinStitchMiter extends JoinStitchHelper
    joinEasy: (dir0, dir1, outerAngle, cw, theta, axisDir, intensity) ->
        if cw
            p0 = {dir: axisDir + Math.PI, side: 0, intensity: intensity}
            p1 = {dir: axisDir, side: 1, intensity: intensity}
        else
            p0 = {dir: axisDir, side: 0, intensity: intensity}
            p1 = {dir: axisDir + Math.PI, side: 1, intensity: intensity}
        return {points: [p0, p1], line0: [0], line1: [1]}


class JoinStitchFanHelper extends JoinStitchHelper
    joinEasy: (dir0, dir1, outerAngle, cw, theta, axisDir, intensity) ->
        if cw
            beginAngle = dir0 - Math.PI / 2
            endAngle = dir1 - Math.PI / 2
        else
            beginAngle = dir1 + Math.PI / 2
            endAngle = dir0 + Math.PI / 2
        fan = @getFan(beginAngle, endAngle)

        if cw
            fanSide = 0
            axisSide = 1
            line0 = [0...fan.length]
            line1 = (fan.length for i in line0)
        else
            fan = fan.reverse()
            fanSide = 1
            axisSide = 0
            line1 = [0...fan.length]
            line0 = (fan.length for i in line1)

        fanPoints = ({dir: d, side: fanSide} for d in fan)
        axisPoint = {dir: axisDir, side: axisSide, intensity: intensity}
        points = fanPoints
        points.push(axisPoint)
        return {points: points, line0: line0, line1: line1}

    getFan: (beginAngle, endAngle) -> throw 'not implemented!'


class JoinStitchRound extends JoinStitchFanHelper
    constructor: (@edges)-> super()

    getFan: (beginAngle, endAngle) ->
        return pacman(beginAngle, endAngle, @edges)


class JoinStitchBevel extends JoinStitchFanHelper
    constructor: (@edges)-> super()

    getFan: (beginAngle, endAngle) ->
        return [beginAngle, endAngle]


module.exports = {
    CapStitch,
    JoinStitch,
    CapStitchRound,
    CapStitchButt,
    CapStitchSquare,
    JoinStitchMiter,
    JoinStitchRound,
    JoinStitchBevel,
}