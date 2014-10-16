/*
required macros:
DIRECTION_RAD
INTENSITY_MULTIPLY
*/

vec4 get_position(vec2 position, float depth,
                  float norm_intensity, float norm_direction, float width,
                  mat4 matrix, mat4 exmatrix) {
    // normalize intensity
    float intensity = norm_intensity * INTENSITY_MULTIPLY + 1.0;

    // normalize direction
    float direction = norm_direction * DIRECTION_RAD;

    vec2 shift = vec4(sin(direction), cos(direction)) * (intensity * width, 0.0, 1.0);

    // XXX: the depth transform here looks wierd, but I suppose it works...
    return matrix * vec4(position, depth, 1.0) + exmatrix * shift;
}
