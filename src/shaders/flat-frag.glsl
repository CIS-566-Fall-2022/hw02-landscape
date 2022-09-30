#version 300 es
precision highp float;

const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 EYE = vec3(0.0, 2.5, 5.0);
const vec3 REF = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);
const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;
vec3 sunLight  = normalize( vec3(  0.4, 0.4,  0.48 ) );
vec3 sunColour = vec3(1.0, .9, .83);


uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

#define SUN_KEY_LIGHT vec3(0.6, 1.0, 0.4) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.7, 0.2, 0.7) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.6, 1.0, 0.4) * 0.2
#define EPSILON 0.01
#define MAXSTEPS 128
#define NEAR 0.1
#define FAR 10.0
#define TWOPI 6.28319

struct Camera {
    vec3 pos;
    vec3 dir;
};

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

vec3 rgb(float r, float g, float b)
{
    return vec3(r / 255.0, g / 255.0, b / 255.0);
}

float unionSDF(float d1, float d2){
    return min(d1, d2);
}

float boxSDF(vec3 p, vec3 b)
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

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
//==================Terrain====================================
float rand (vec2 st) {
    return fract(sin(dot(st.xy,vec2(12.9898,78.233)))*43758.5453123);
}

vec2 grad (vec2 st) {
    float nn = rand(st);
    return vec2(cos(nn * TWOPI), sin(nn * TWOPI));
}

float gradnoise (vec2 st) {
    // returns range -1, 1
    vec2 pa = floor(st);
    vec2 pb = pa + vec2(1.0, 0.0);
    vec2 pc = pa + vec2(0.0, 1.0);
    vec2 pd = pa + vec2(1.0);
    vec2 ga = grad(pa);
    vec2 gb = grad(pb);
    vec2 gc = grad(pc);
    vec2 gd = grad(pd);
    float ca = dot(ga, st - pa);
    float cb = dot(gb, st - pb);
    float cc = dot(gc, st - pc);
    float cd = dot(gd, st - pd);
    vec2 frast = fract(st);
    return mix(
        mix(ca, cb, mix(0.0, 1.0, frast.x)),
        mix(cc, cd, mix(0.0, 1.0, frast.x)),
        mix(0.0, 1.0, frast.y));
}

float perlin (vec2 st, float scale, float freq, float persistence, float octaves) {
    float p = 0.0;
    float amp = 1.0;
    for (float i=0.0; i<octaves; i++) {
        p += gradnoise(st * freq / scale) * amp;
        amp *= persistence;
        freq *= 2.0;
    }
    return p;
}

//================Fog================
vec3 GetSky(in vec3 rd)
{
    float sunAmount = max( dot( rd, sunLight), 0.0 );
    float v = pow(1.0-max(rd.y,0.0),5.) * .5;
    vec3  sky = vec3(v * sunColour.x * 0.4+0.18, v * sunColour.y * 0.4+0.22, v * sunColour.z * 0.4+.4);
    // Wide glare effect...
    sky = sky + sunColour * pow(sunAmount, 6.5) * .32;
    // Actual sun...
    sky = sky + sunColour * min(pow(sunAmount, 1150.0), .3) * .65;
    return sky;
}
vec3 ApplyFog( in vec3  rgb, in float dis, in vec3 dir)
{
    float fogAmount = exp(-dis * 0.00005);
    return mix(GetSky(dir), rgb, fogAmount );
}

float sdfSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdfPerlin(vec3 p) {
    return p.y + 4.0 * perlin(p.xz, 6.0, 0.5, 0.5, 5.0) + 0.5;
}
//==================Mushroom===================================
float mushroom(vec3 queryPos){
    float sphere = sphereSDF(queryPos, vec3(0.0, 1.4, -5.0), 1.0);
    float box = boxSDF(queryPos, vec3(0.0, 1.4, -4.0));
    float upPart = smoothSubtraction(box, sphere, 0.2);
    float capsuleRoot = capsuleSDF(queryPos, vec3(0.0, 0.5, 0.0), vec3(0.0, 1.5, 0.0), 0.3);
        
    float mushroom = smoothUnion(upPart, capsuleRoot, 0.2);
    return mushroom;
}

float sceneSDF(vec3 queryPos)
{

    //float plane = planeSDF(queryPos, -1.0);
    
    //float moon1 = sdfSphere(p + vec3(-60.0, -40.0, -70.0), 5.0);
    //float moon2 = sdfSphere(p + vec3(-30.0, -20.0, -70.0), 2.0);
    float land = sdfPerlin(vec3(queryPos.x, queryPos.y, queryPos.z));
//
//    float mushrooms = 0.0;
//
//    vec3 offset = vec3(2.0, 0.0, 0.0);
    //float mushroom1 = mushroom(queryPos);
    //mushrooms = mushroom1;
    //float sphere = sphereSDF(queryPos, vec3(0.0, 1.4, -5.0), 1.0);

   // return plane;
    return land;
    //return min(min(moon1, moon2), land);
    
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

//vec3 estimateNormal(vec3 p) {
//    return normalize(vec3(
//        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
//        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
//        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
//    ));
//}
vec3  estimateNormal(vec3 p) {
    vec3 v1 = vec3(1.0, -1.0, -1.0);
    vec3 v2 = vec3(-1.0, -1.0, 1.0);
    vec3 v3 = vec3(-1.0, 1.0, -1.0);
    vec3 v4 = vec3(1.0, 1.0, 1.0);
    return normalize(
        v1 * sceneSDF(p + v1*EPSILON) +
        v2 * sceneSDF(p + v2*EPSILON) +
        v3 * sceneSDF(p + v3*EPSILON) +
        v4 * sceneSDF(p + v4*EPSILON)
    );
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
            intersection.normal = estimateNormal(queryPoint);
            intersection.distance = length(queryPoint - ray.origin);

            return intersection;
        }

        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }

    intersection.distance = -1.0;
    return intersection;
}


//vec3 getSceneColor(vec2 uv)
//{
//    Intersection intersection = getRaymarchedIntersection(uv);
//    vec3 color = vec3(0.0);
//    if (intersection.distance > 0.0)
//    {
//        color += rgb(25.0, 190.0, 20.0)
//        * max(0.0, dot(intersection.normal, vec3(0.0, 7.4, -5.0) - intersection.position)) ;
//
//    }
//    else
//    {
//        color = vec3(0.5, 0.7, 0.9);
//    }
//
//    color = pow(color, vec3(1. / 2.2));
//    return color;
//}

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
float distToSurface(Camera c, out vec3 ip) {
    float depth = NEAR;
    for (int i=0; i<MAXSTEPS; i++) {
        ip = c.pos + c.dir * depth;
        float distToScene = sceneSDF(ip);
        if (distToScene < EPSILON) {
            return depth;
        }
        depth += distToScene;
        if (depth >= FAR) {
            return FAR;
        }
    }
    return depth;
}

float lambert(vec3 norm, vec3 lpos) {
    return max(dot(norm, normalize(lpos)), 0.0);
}



void main() {
//    //vec2 uv = fs_Pos.xy/u_Dimensions.xy;
//
//        // Make symmetric [-1, 1]
//    //uv = uv * 2.0 - 1.0;
//
//        // Time varying pixel color
    vec3 col = getSceneColor(fs_Pos.xy);
    
    col = ApplyFog(col, 2.0, u_Ref);
//
//        // Output to screen
    out_Col = vec4(col, 1.0);
//    //out_Col = vec4(0.0, 1.0, 1.0, 1.0);
//    //out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
    
    
    
    
}
