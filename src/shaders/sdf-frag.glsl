#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

//Constants:
#define EPSILON 1e-2
#define MAX_RAY_STEPS 512
#define MAX_DISTANCE 100.0


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

//Noise Functions:

vec2 hash( vec2 p )
{
	p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

//IQ
float noise(vec2 p )
{
    const float K1 = 0.366025404; // (sqrt(3)-1)/2;
    const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2  i = floor( p + (p.x+p.y)*K1 );
    vec2  a = p - i + (i.x+i.y)*K2;
    float m = step(a.y,a.x); 
    vec2  o = vec2(m,1.0-m);
    vec2  b = a - o + K2;
	vec2  c = a - 1.0 + 2.0*K2;
    vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	vec3  n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i + o)), dot(c,hash(i+1.0)));
    return dot( n, vec3(70.0) );
}

float fbm(vec2 p, int N_OCTAVES) {

    float total = 0.f;
    float frequency = 1.f;
    float amplitude = 1.f;
    float persistence = 0.5f;
    float maxValue = 0.f;  // Used for normalizing result to 0.0 - 1.0

    for(int i = 0; i < N_OCTAVES; i++) {
        total += noise(frequency * p) * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= 2.f;
    }
    return total/maxValue;
    // return 1.f;
}

//SDF Functions:



Geom union_Geom(Geom g1, Geom g2) {
    Geom g;
    if (g1.distance < g2.distance) {
        return g1;
    } else {
        return g2;
    }
}

Geom sdBox_Geom( vec3 p, vec3 b, vec3 pos, int id)
{
    Geom g;
    p -= pos;
    vec3 q = abs(p) - b;
    g.distance = length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    g.material_id = id;
    return g;
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

    // Geom train = sdBox_Geom(queryPos, vec3(35.0f, 1.f, 1.f), vec3(u_Ref.x, u_Ref.y - 0.1f, u_Ref.z + 10.f), 0);
    //The train is 2 units away from us...

    Geom plane;
    // if (queryPos.z < 80.f) {
    //     plane = planeSDF_Geom(queryPos, 0.0, 4);
    // }
    // else if (queryPos.z < 82.f) {
    // if (queryPos.z < 70.f) {
    //     // plane = planeSDF_Geom(queryPos, 0.9f * abs(sin(queryPos.x)), 1);
    //     plane = planeSDF_Geom(queryPos, 1.0f, 1);
    // } else if (queryPos.z < 90.f) {
    //     float hT = mix(1.f, 0.f, (queryPos.z - 85.f)/5.f);
    //     plane = planeSDF_Geom(queryPos, hT, 1);
    // } else {
    //     plane = planeSDF_Geom(queryPos, 0.0, 4);
    // }

    if (queryPos.z < 80.f) {
        plane = planeSDF_Geom(queryPos, sin(queryPos.z - 80.f), 1);
    } else {
        plane = planeSDF_Geom(queryPos, 0.f, 1);
    }
    // plane = planeSDF_Geom(queryPos, sin(queryPos.z), 1);
    // }
    // } else if (queryPos.z < 84.f) { //
    //     plane = planeSDF_Geom(queryPos, 0.0, 2);
    //     //Generate a lookup table for the plane's noise ...
    // } else if (queryPos.z < 90.f){
    //     plane = planeSDF_Geom(queryPos, 0.0, 3);
    // } else {
    //     plane = planeSDF_Geom(queryPos, 0.0, 5);
    // }

    // if (queryPos.x < 0.f) {
    //     plane = planeSDF_Geom(queryPos, 0.0, 4);
    // }
    
    // return sphere;
    // return union_Geom(train, plane);
    return plane;
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
    sceneSDF(vec3(p.x, p.y, p.z + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
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
        // if (isect.material_id == 0) {
        //     color = vec3(1.);
        // } else if (isect.material_id == 1) {
        //     color = vec3(0.2);
        // } else if (isect.material_id == 2) {
        //     color = vec3(0.4);
        // } else if (isect.material_id == 3) {
        //     color = vec3(0.5);
        // } else if (isect.material_id == 4) {
            // color = vec3(0.1);
        // }else {
            vec3 N = estimateNormal(isect.position);
            color = N;
        // }
    } else {
        color = vec3(0.67, 0.81, 0.88);
    }

    vec3 backgroundColor = vec3(0.67, 0.81, 0.88);
    // float fogT = smoothstep(10.0, 35.0, distance(isect.position, u_Eye));
    // color = mix(color.rgb, backgroundColor, fogT);
    // color = pow(color.rgb, vec3(1.0, 1.2, 1.5));
    return color;
}

void main() {
    vec2 uv = fs_Pos;
    //uv is in NDC space!

    vec3 color = getSceneColor(uv);
    out_Col = vec4(color, 1.f);
}
