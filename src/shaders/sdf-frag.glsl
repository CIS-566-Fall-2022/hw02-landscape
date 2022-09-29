#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec4 u_Color;

in vec2 fs_Pos;
out vec4 out_Col;

#define EPSILON          0.0001
#define INFINITY         1000000.0
#define MAX_STEPS        64
#define MAX_DEPTH        100.0

struct Ray
{
    vec3 origin;
    vec3 direction;
};

struct Intersection
{
    float t;
};

// SDF for a sphere centered at objectPos
float sphereSDF(vec3 rayPos, vec3 objectPos, float radius)
{
    return length(rayPos - objectPos) - radius;
}

Ray getRay(vec2 uv)
{
    Ray ray;

    float aspect = u_Dimensions.x / u_Dimensions.y;
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * aspect;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);

    ray.origin = u_Eye;
    ray.direction = dir;
    return ray;
}

Intersection Raymarch(vec2 uv, Ray ray)
{
    Intersection intersection;

    /*// Raymarch scene
    float depth = 0.f;
    for (int i = 0; i < MAX_STEPS; ++i)
    {       
        vec3 p = ray.origin + depth * ray.direction;
        float dist = sphereSDF(p, vec3(0.0, 0.0, 0.0), 0.5);
        depth += dist;
        if (dist < EPSILON || depth > MAX_DEPTH) break;
    }
    intersection.t = depth;
    return intersection;*/

    vec3 p = ray.origin;
    for (int i = 0; i < MAX_STEPS; ++i)
    {       
        float dist = sphereSDF(p, vec3(0.0, 0.0, 0.0), 0.5);
        if (dist < EPSILON)
        {
            intersection.t = length(p - ray.origin);
            return intersection;
        }
        p = p + dist * ray.direction;
    }
    intersection.t = -1.0;
    return intersection;
}

void main() {

    // Material base color (before shading)
    vec4 diffuseColor = vec4(0.0, 0.0, 0.0, 1.0);

    vec2 uv = (gl_FragCoord.xy - .5 * u_Dimensions.xy) / u_Dimensions.y;
    Ray ray = getRay(uv);
    Intersection isect = Raymarch(uv, ray);

    if (isect.t > 0.0) {
        diffuseColor = vec4(vec3(1.0), 1.0);
    }
    //diffuseColor = vec4(vec3(isect.t) * .005, 1.0);

    // Compute final shaded color
    out_Col = vec4(diffuseColor.rgb, diffuseColor.a);
}
