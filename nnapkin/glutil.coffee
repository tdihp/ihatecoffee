createShader = (gl, src, type) ->
	shader = gl.createShader(type)

	gl.shaderSource(shader, src)
	gl.compileShader(shader)

	if !gl.getShaderParameter(shader, gl.COMPILE_STATUS)
        t = if type == gl.VERTEX_SHADER then "VERTEX" else "FRAGMENT"
        alert("#{t} SHADER: #{gl.getShaderInfoLog(shader)}")
        return null

	return shader


initProgram = (gl, vertexShader, fragmentShader) ->
    program = gl.createProgram()
    vs = createShader(gl, vertexShader, gl.VERTEX_SHADER)
    fs = createShader(gl, fragmentShader, gl.FRAGMENT_SHADER)
    
    if vs == null or fs == null
        alert 'oops, initProgram failed'
        return null
    
    gl.attachShader(program, vs)
    gl.attachShader(program, fs)
    gl.deleteShader(vs)
    gl.deleteShader(fs)
    gl.linkProgram(program)
    
    if !gl.getProgramParameter(program, gl.LINK_STATUS)
        alert """
link error: 
    VALIDATE_STATUS: #{ gl.getProgramParameter(program, gl.VALIDATE_STATUS) }
    ERROR: #{gl.getError()}"""
        return null
    return program


initGLNamespace = (gl, namespace='nnapkin') ->
    ###add a place holder namespace for us###
    if not gl[namespace]
        gl[namespace] = {}


module.exports = {
    createShader,
    initProgram,
}
