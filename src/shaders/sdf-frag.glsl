#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

//Constants:
#define EPSILON 1e-2
#define MAX_RAY_STEPS 128
#define MAX_DISTANCE 50.0

const vec3 EYE = vec3(0.0, 2.5, 5.0);
const vec3 REF = vec3(0.0, 1.0, 0.0);



//Structs:

//SDF Functions:

float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

float sceneSDF(vec3 queryPos) {
    float plane = planeSDF(queryPos, 0.0);
    // return plane;
    float sphere = sphereSDF(queryPos, vec3(0.0,1.5,0.0), 1.0);
    // return sphere;
    return min(sphere, plane);
}

//Helper Functions:

vec3 getRay(vec2 uv) {
    float len = tan(3.14159 * 0.125) * distance(EYE, REF);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), REF - EYE));
    vec3 V = normalize(cross(H, EYE - REF));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = REF + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - EYE);
    return dir;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

float rayMarchSimple(vec2 uv)
{
    vec3 dir = getRay(uv);
    float depth = 0.0;
    for (int i=0; i < MAX_RAY_STEPS && depth < MAX_DISTANCE; ++i)
    {
        float dist = sceneSDF(EYE + depth * dir);
        
        if (dist < EPSILON)
        {
            return depth;
        }

        depth += dist;
    }
    return -1.f;
}

vec3 getSceneColor(vec2 uv) {
    //1. Ray March to get sceneSDF!
    float intersection = rayMarchSimple(uv);
    //2. Choose color based on distance value (but also, in future, we can categorize by material too...)
    vec3 color;
    if (intersection > 0.0) {
        color = vec3(0.9, 0.0, 0.2);
    } else {
        color = vec3(0.3, 0.4, 0.9);
    }
    return color;
}

void main() {
    vec2 uv = fs_Pos;
    //uv is in NDC space!

    vec3 color = getSceneColor(uv);
    out_Col = vec4(color, 1.f);
}
