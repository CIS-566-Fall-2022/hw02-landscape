#version 300 es

precision highp float;

uniform vec2 u_Dimensions;
// uniform float u_Fov;
uniform float u_Time;
// uniform vec3 u_EyePos;
// uniform mat4 u_ViewInv; 
// uniform sampler2D u_BackgroundTexture;

out vec4 out_Col;

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;

float sphereSDF (vec3 point) {
    return length(point) - 1.0;
}

float sceneSDF (vec3 point) {
    return sphereSDF(point);
}

float raymarch (vec3 eye, vec3 marchDir, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchDir);
        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}

vec3 rayDirection (float fov, vec2 size, vec2 uv) {
    vec2 xy = uv - size / 2.0;
    float z = (size.y / 2.0) / tan(radians(fov) / 2.0);
    return normalize(vec3(xy, -z));
}

vec3 estimateNormal (vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

void main () {
    vec3 dir = rayDirection(45.0, u_Dimensions, vec2(gl_FragCoord.x, gl_FragCoord.y));
    vec3 eye = vec3(0.0, 0.0, 5.0);
    float dist = raymarch(eye, dir, MIN_DIST, MAX_DIST);

    if (dist > MAX_DIST - EPSILON) {
        // didn't hit anything
        out_Col = vec4(0.0, 0.0, 0.0, 0.0);
		return;
    }

    out_Col = vec4(1.0, 0.0, 0.0, 1.0);
}





