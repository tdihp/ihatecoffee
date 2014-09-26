/*
required macros:
STYLE_SIZE
DIRECTION_RAD
INTENSITY_MULTIPLY
*/
attribute vec2 a_position;
attribute float a_direction;
attribute float a_stroke;
attribute float a_intensity;
uniform vec2 u_resolution;
uniform vec4 u_palette[STYLE_SIZE];
uniform float u_widths[STYLE_SIZE];
varying vec4 v_color;


void main() {
    // normalize intensity
    float intensity = (a_intensity / 255.0) * INTENSITY_MULTIPLY + 1.0;

    // normalize direction
    float direction = a_direction * DIRECTION_RAD;
    
    int stroke = int(a_stroke);
    v_color = u_palette[stroke];
    
    vec2 shift = vec2(sin(direction), cos(direction)) * (intensity * u_widths[stroke]);

    vec2 position = a_position + shift;

    // convert the rectangle from pixels to 0.0 to 1.0
    vec2 zeroToOne = position / u_resolution;

    // convert from 0->1 to 0->2
    vec2 zeroToTwo = zeroToOne * 2.0;

    // convert from 0->2 to -1->+1 (clipspace)
    vec2 clipSpace = zeroToTwo - 1.0;
   
    // flipped
    //gl_Position = vec4(clipSpace * vec2(1, -1), 0, 1);

    gl_Position = vec4(clipSpace, 0, 1);
}