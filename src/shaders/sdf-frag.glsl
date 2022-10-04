#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

//Constants:
#define EPSILON 1e-2
#define MAX_RAY_STEPS 256
#define MAX_DISTANCE 1000.0


//Structs:

struct Intersection 
{
    vec3 position;
    float t;
    int material_id;
};

struct Geom
{
    float distance;
    int material_id;
};

//Material List:

//0: 
//1: 
//...

//SDF Functions:


Geom union_Geom(Geom g1, Geom g2) {
    Geom g;
    if (g1.distance < g2.distance) {
        return g1;
    } else {
        return g2;
    }
}

Geom sdRoundBox_Geom( vec3 p, vec3 b, vec3 pos, float r, int id)
{
    Geom g;
    p -= pos;
    vec3 q = abs(p) - b;
    g.distance = length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
    g.material_id = id;
    return g;
}

Geom sphereSDF_Geom(vec3 query_position, vec3 position, float radius, int id)
{
    Geom g;
    g.distance = length(query_position - position) - radius;
    g.material_id = id;
    return g;
}

Geom planeSDF_Geom(vec3 queryPos, float height, int id)
{
    Geom g;
    g.distance = queryPos.y - height;
    g.material_id = id;
    return g;
}

Geom sceneSDF_Geom(vec3 queryPos) {
    Geom sphere = sphereSDF_Geom(queryPos, vec3(0.0,2.5,0.0), 1.0, 0);
    Geom plane = planeSDF_Geom(queryPos, 0.0, 1);
    //( vec3 p, vec3 b, float r, int id)
    Geom train = sdRoundBox_Geom(queryPos, vec3(10.f, 1.f, 0.5f), vec3(0.f, 0.0f, -80.f), 0.4f, 0);
    // return sphere;
    return union_Geom(train, plane);
}

float sceneSDF(vec3 queryPos) {
    return sceneSDF_Geom(queryPos).distance;
}

//Helper Functions:
vec3 getRay(vec2 uv) {
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);
    return dir;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

//Ray Marching
Intersection rayMarch(vec2 uv)
{
    Intersection intersection;
    intersection.t = 0.001;

    vec3 dir = getRay(uv);
    vec3 queryPos = u_Eye;

    for (int i=0; i < MAX_RAY_STEPS && intersection.t < MAX_DISTANCE; ++i)
    {
        Geom g = sceneSDF_Geom(queryPos);
        float dist = g.distance;
        
        if (dist < EPSILON)
        {
            intersection.position = queryPos;
            intersection.t = length(queryPos - u_Eye);
            intersection.material_id = g.material_id;
            return intersection;
        }
        queryPos += dir * dist;
    }
    
    intersection.t = -1.0;
    return intersection;
}

//Coloring:
vec3 getSceneColor(vec2 uv) {
    //1. Ray March to get scene intersection / or lack there of
    Intersection isect = rayMarch(uv);
    //2. Choose color based on distance value (but also, in future, we can categorize by material too...)
    vec3 color;
    if (isect.t > 0.0) {
        // vec3 N = estimateNormal(isect.position);
        // color = N;
        if (isect.material_id == 0) {
            vec3 N = estimateNormal(isect.position);
            color = N;
        } else {
            color = vec3(1.);
        }
    } else {
        color = vec3(0.2, 0.2, 0.4);
    }
    return color;
}

void main() {
    vec2 uv = fs_Pos;
    //uv is in NDC space!

    vec3 color = getSceneColor(uv);
    out_Col = vec4(color, 1.f);
}
