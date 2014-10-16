//#include "line.include.vertex.glsl"
/*
required macros:
PALETTE_SIZE
TEXTURE_HEIGHT
*/
uniform mat4 u_matrix;  // depth offset included
uniform mat4 u_exmatrix;
uniform vec4 u_palette[PALETTE_SIZE];
uniform float u_widths[PALETTE_SIZE];
uniform float u_dash_cycles[PALETTE_SIZE];

attribute vec2 a_position;
attribute float a_depth;
attribute float a_direction;
attribute float a_palette_index;
attribute float a_intensity;
attribute float a_line_sofar;

varying vec2 v_tex;
varying vec4 v_color;


void main() {
    int palette_index = int(a_palette_index);
    gl_Position = get_position(
        a_position, a_depth,
        a_intensity, a_direction, u_widths[palette_index],
        matrix, exmatrix);
    v_color = u_palette[palette_index];
    // linear filter should be good for antialias (?)
    v_tex.x = a_line_sofar / u_dash_cycles[palette_index];
    // y must be pixel-exact here to avoid texture bleeding
    // http://gamedev.stackexchange.com/questions/46963/how-to-avoid-texture-bleeding-in-a-texture-atlas
    v_tex.y = (a_palette_index + 0.5) / float(TEXTURE_HEIGHT);
}