precision mediump float;

uniform sampler2D u_sampler;

varying vec2 v_tex;
varying vec4 v_color;


void main() {
    // multiply alpha chanel only
    gl_FragColor = v_color * texture2D(u_sampler, v_tex);
}