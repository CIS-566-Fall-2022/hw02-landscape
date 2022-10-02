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

// phong light contribution
// k_s = specular reflection constant, ratio of reflection of the specular term of incoming light
// k_d = diffuse reflection constant, ratio of reflection of the diffuse term of incoming light
// k_a = ambient reflection constant, ratio of reflection of the ambient term present in all points in scene rendered
// alpha = shininess constant for the material
vec3 lightContrib (vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye, vec3 lightPos, vec3 intensity) {
    vec3 N = estimateNormal(p);
    vec3 L = normalize(lightPos - p);
    vec3 V = normalize(eye - p);
    vec3 R = normalize(reflect(-L, N));
    
    float dotLN = dot(L, N);
    float dotRV = dot(R, V);
    
    if (dotLN < 0.0) {
        // light not visible from this point on the surface
        return vec3(0.0, 0.0, 0.0);
    } 
    
    if (dotRV < 0.0) {
        // light reflection in opposite direction, apply only diffuse component
        return intensity * (k_d * dotLN);
    }
    return intensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
}

// phong illumination
vec3 illumination (vec3 k_a, vec3 k_d, vec3 k_s, float alpha, vec3 p, vec3 eye) {
    const vec3 ambient = 0.5 * vec3(1.0, 1.0, 1.0);
    vec3 color = ambient * k_a;
    
    vec3 lightPos1 = vec3(4.0 * sin(u_Time * 0.03), 2.0, 4.0 * cos(u_Time * 0.03));
    vec3 lightIntensity1 = vec3(0.4, 0.4, 0.4);
    
    color += lightContrib(k_d, k_s, alpha, p, eye, lightPos1, lightIntensity1);
    
    vec3 lightPos2 = vec3(2.0 * sin(0.37 * u_Time * 0.03), 2.0 * cos(0.37 * u_Time * 0.03), 2.0);
    vec3 lightIntensity2 = vec3(0.4, 0.4, 0.4);
    
    color += lightContrib(k_d, k_s, alpha, p, eye, lightPos2, lightIntensity2);    
    return color;
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

    vec3 p = eye + dist * dir;
    
    vec3 kA = vec3(0.2, 0.2, 0.2);
    vec3 kD = vec3(0.7, 0.2, 0.2);
    vec3 kS = vec3(1.0, 1.0, 1.0);
    float shiny = 10.0;
    
    vec3 color = illumination(kA, kD, kS, shiny, p, eye);

    out_Col = vec4(color, 1.0);
}





