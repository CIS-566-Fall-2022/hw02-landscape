#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;


in vec2 fs_Pos;
out vec4 out_Col;

///////////////////////////////////////////////////////////////////////////////////////
const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

//const vec3 u_Eye = vec3(0.0, 2.5, 5.0);
// const vec3 REF = vec3(0.0, 1.0, 0.0);
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

//generates a plane at y = height
//returns the diffence in y positions
//queryPos
float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height + sin(queryPos.x)*sin(queryPos.z);
}

float terrainSDF(vec3 queryPos, float height)
{ //(queryPos.y - height) 
    return sin(queryPos.x)*sin(queryPos.z);
}

float capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
  vec3 pa = queryPos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float smoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

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

//////////////////////////////////////////////////////////////////////////////////////////////////

//all sdfs go here
float sceneSDF(vec3 queryPos) 
{
    float plane = planeSDF(queryPos, 0.0);
    float terrain = terrainSDF(queryPos, 0.);
    return plane;
    // return sphereSDF(queryPos, vec3(0., 1., 0.), 1.);
}


Ray getRay(vec2 uv) {
    Ray ray;
    
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);
    
    ray.origin = u_Eye;
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
    // lights[1] = DirectionalLight(vec3(0., 1., 0.),
    //                              SKY_FILL_LIGHT);
    // lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
    //                              SUN_AMBIENT_LIGHT);
    
    // lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
    //                              SUN_KEY_LIGHT);
    // lights[1] = DirectionalLight(vec3(0., 1., 0.),
    //                              SKY_FILL_LIGHT);
    // lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
    //                              SUN_AMBIENT_LIGHT);
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

void main() {
  //get uv coords in -1,1 domain for x and y
  vec2 uv = (vec2(gl_FragCoord.xy) /u_Dimensions) * 2. - 1.;
  // vec3 camera_position = u_u_Eye; 
  // vec3 ro = u_u_Eye; //ray origin start at camera init at (0,0,-10)
  // vec3 rd = vec3(uv, 1.0);
  // vec3 shaded_color = ray_march(ro, rd);
  // out_Col = vec4(shaded_color, 1.0);

  vec3 col = getSceneColor(uv);
  // out_Col = color = vec3(0.5, 0.7, 0.9);
  out_Col = vec4(col, 1.);

  
  // out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}
