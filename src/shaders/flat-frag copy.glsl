#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;


// ------------- COMMON ----------------
const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 EYE = vec3(0.0, 2.5, 5.0);
const vec3 REF = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);
const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;

// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define SUN_KEY_LIGHT vec3(0.6, 1.0, 0.4) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.7, 0.2, 0.7) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.6, 1.0, 0.4) * 0.2

struct Ray 
{
    vec3 origin;
    vec3 direction;
};

struct Intersection 
{
    vec3 position;
    vec3 normal;
    float distance;
    int material_id;
};

struct DirectionalLight
{
    vec3 dir;
    vec3 color;
};


float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

float capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
  vec3 pa = queryPos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float RoundBoxSDF( vec3 p, vec3 b)
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float smoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); }


float smoothSubtraction( float d1, float d2, float k ) 
{
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h); 
}

float smoothIntersection( float d1, float d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) + k*h*(1.0-h);
}


vec3 bendPoint(vec3 p, float k)
{
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xy,p.z);
    return q;
}

// -------------- COMMON END -------------------



// ---------------- MUSHROON -------------------

float mushroomSDF(vec3 queryPos) 
{
    float mushroomT = sphereSDF(queryPos, vec3(0.0, 1.5, 0.0), 1.0);
    float mushroomB = RoundBoxSDF(queryPos, vec3(1.0, 1.5, 1.0));
    float dt1 = smoothSubtraction(mushroomB, mushroomT, 0.1);
    
    float root = capsuleSDF(queryPos, vec3(0.0, 0.5, 0.0), vec3(0.0, 1.5, 0.0), 0.2);
    
    float dt2 = smoothUnion(dt1, root, 0.3);
    return dt2;
}

float sceneSDF(vec3 queryPos) 
{
    vec3 offset = vec3(-2.0, 0.0, 0.0);
    float plane = planeSDF(queryPos, 0.0);
    vec3 bendPos = bendPoint(queryPos + offset, 0.5 * sin(1.5 * 0.01 * u_Time));
    float mushroom = mushroomSDF(bendPos + vec3(0.0, 0.4, 0.0));
    float dt1 = smoothUnion(plane, mushroom, 0.1);
    
    offset += vec3(2.0, 0.0, 0.0);
    vec3 bendPos1 = bendPoint(queryPos + offset, 0.5 * -sin(1.5 * 0.01 * u_Time));
    float mushroom1 = mushroomSDF(bendPos1 + vec3(0.0, 0.4, 0.0));
    float dt2 = smoothUnion(plane, mushroom1, 0.1);
    
    offset += vec3(2.0, 0.0, 0.0);
    vec3 bendPos2 = bendPoint(queryPos + offset, 0.5 * cos(1.2 * 0.01 * u_Time));
    float mushroom2 = mushroomSDF(bendPos2 + vec3(0.0, 0.4, 0.0));
    float dt3 = smoothUnion(plane, mushroom2, 0.05);
    
    float dt = smoothUnion(dt1, dt2, 0.05);
    dt = smoothUnion(dt, dt3, 0.1);
    return dt;
}


Ray getRay(vec2 uv) {
    Ray ray;
    
    float len = tan(3.14159 * 0.125) * distance(EYE, REF);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), REF - EYE));
    vec3 V = normalize(cross(H, EYE - REF));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = REF + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - EYE);
    
    ray.origin = EYE;
    ray.direction = dir;
    return ray;
}

Intersection getRaymarchedIntersection(vec2 uv)
{
    Ray ray = getRay(uv);
    Intersection intersection;
    
    vec3 queryPoint = ray.origin;
    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        float distanceToSurface = sceneSDF(queryPoint);
        
        if (distanceToSurface < EPSILON)
        {
            
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);
            
            return intersection;
        }
        
        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }
    
    intersection.distance = -1.0;
    return intersection;
}


vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}

vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    backgroundColor = SUN_KEY_LIGHT;
    
    vec3 albedo = vec3(0.5);
    vec3 n = estimateNormal(intersection.position);
        
    vec3 color = albedo *
                 lights[0].color *
                 max(0.0, dot(n, lights[0].dir));
    
    if (intersection.distance > 0.0)
    { 
        for(int i = 1; i < 3; ++i) {
            color += albedo *
                     lights[i].color *
                     max(0.0, dot(n, lights[i].dir));
        }
    }
    else
    {
        color = vec3(0.5, 0.7, 0.9);
    }
        color = pow(color, vec3(1. / 2.2));
        return color;
}


//---------------- MUSHROON END -------------------



// --------------- TEST SPHERE --------------------
#define MAX_STEPS 100
#define MAX_DIST 100.
#define SURF_DIST .01

float GetDist(vec3 p) {
	vec4 s = vec4(0, 1, 6, 1);
    
  float sphereDist =  length(p-s.xyz)-s.w;
  float planeDist = p.y;
  
  float d = min(sphereDist, planeDist);
  return d;
}

float RayMarch(vec3 ro, vec3 rd) {
	float dO=0.;
    
    for(int i=0; i<MAX_STEPS; i++) {
    	vec3 p = ro + rd*dO;
        float dS = GetDist(p);
        dO += dS;
        if(dO>MAX_DIST || dS<SURF_DIST) break;
    }
    
    return dO;
}

vec3 GetNormal(vec3 p) {
	float d = GetDist(p);
    vec2 e = vec2(.01, 0);
    
    vec3 n = d - vec3(
        GetDist(p-e.xyy),
        GetDist(p-e.yxy),
        GetDist(p-e.yyx));
    
    return normalize(n);
}

float GetLight(vec3 p) {
    vec3 lightPos = vec3(0, 5, 6);
    lightPos.xz += vec2(sin(u_Time * 0.01), cos(u_Time * 0.01))*2.;
    vec3 l = normalize(lightPos-p);
    vec3 n = GetNormal(p);
    
    float dif = clamp(dot(n, l), 0., 1.);
    float d = RayMarch(p+n*SURF_DIST*2., l);
    if(d<length(lightPos-p)) dif *= .1;
    
    return dif;
}

// --------------- TEST SPHERE END --------------------

void main() {
  // Normalized pixel coordinates (from 0 to 1)
  vec2 uv = gl_FragCoord.xy/u_Dimensions.xy;

  // Make symmetric [-1, 1]
  uv = uv * 2.0 - 1.0;

  // Time varying pixel color
  vec3 col = getSceneColor(uv);

  // Output to screen
  out_Col = vec4(col,1.0);
  //out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}
