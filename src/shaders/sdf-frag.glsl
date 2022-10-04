#version 300 es
precision highp float;

uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec3 u_Eye, u_Ref, u_Up;

in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

out vec4 out_Col;

const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 EYE = vec3(-0.45, 2.24, 5.0);
// const vec3 EYE = vec3(0.0, 2.5, 5.0);
const vec3 REF = vec3(0.0, 2.5, 0.0);
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

const vec3 colors[6] = vec3[](vec3(99, 5, 0) / 255.0,         // MARRON
                            vec3(128, 6, 4) / 255.0,        // RED
                            vec3(245, 96, 55) / 255.0,     // DARK ORANGE
                            vec3(255, 151, 56) / 255.0,     // ORANGE
                            vec3(249, 222, 81) / 255.0,     // YELLOW
                            vec3(251,225,106) / 255.0);    // LIGHT YELLOW

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float map2(float value, float min, float max){
	return clamp((value - min)/(max - min), 0.f, 1.f);
}

//=========================

const float PI = 3.14159265359;

float noise2D( vec2 p ) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cosineInterpolate(float a, float b, float t) {
  float cos_t = (1.0 - cos(t * PI)) * 0.5f;
  return mix(a, b, cos_t);
}

vec2 rotate(vec2 p, float deg) {
        float rad = deg * 3.14159 / 180.0;
        return vec2(cos(rad) * p.x - sin(rad) * p.y,
                    sin(rad) * p.x + cos(rad) * p.y);
}

float interpNoise2D(float x, float y) {
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);

    float v1 = noise2D(vec2(intX, intY));
    float v2 = noise2D(vec2(intX + 1, intY));
    float v3 = noise2D(vec2(intX, intY + 1));
    float v4 = noise2D(vec2(intX + 1, intY + 1));

    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);

    return cosineInterpolate(i1, i2, fractY);
}

float fbm(vec2 p, float persistence, int octaves) {
    float total = 0.0;
    for(int i = 1; i <= octaves; i++) {
        float freq = pow(2.0f, float(i));
        float amp = pow(persistence, float(i));
        total += interpNoise2D(p.x * freq, p.y * freq) * amp;
    }
    return total;
}

vec2 vectorFBM(vec2 uv, float persistence, int octaves, float deg) {
        float x = fbm(uv, persistence, octaves);
        float y = fbm(rotate(vec2(uv.x, uv.y), deg), persistence, octaves);
        return vec2(x, y);
}

//==================

vec3 getColor(int ID, vec3 p)
{
  vec3 c = vec3(0.0);
  switch(ID)
  {
    case 0:
      // terrain
      c = mix(colors[0], colors[3], smoothstep(0.4, 0.6, map(p.y, 0.0, 5.2, 0.0, 1.0)));
      break;
    case 1:
      // water
      c = colors[1] + colors[2] * 0.02 * (sin((-p.x + p.z) * 100.2 + (u_Time * 0.8)));
      break;
    default:
    c = vec3(1.0);
      break;
  }
  return c;
}

vec3 applyFog( in vec3  rgb,      // original color of the pixel
               in float distance, // camera to point distance
               in vec3  rayDir,   // camera to point vector
               in vec3  sunDir )  // sun light direction
{
    float fogAmount = 1.0 - exp( -distance * 0.3 );
    float sunAmount = max( dot( rayDir, sunDir ), 0.0 );
    vec3  fogColor  = mix( vec3(0.5,0.2,0.15)*1.2, vec3(1.1,0.6,0.45)*1.3,
                           pow(sunAmount,8.0) );
    return mix( rgb, fogColor, fogAmount );
}

vec3 scatter(vec3 ro, vec3 rd, vec3 lgt)
{   
    float sd= max(dot(lgt, rd) * 0.5 + 0.5, 0.f);
    float dtp = 13.f-(ro + rd * float(MAX_RAY_STEPS)).y * 3.5;
    float hori = (map2(dtp, -1500.f, 0.0) - map2(dtp, 11.f, 500.f)) * 1.f;
    hori *= pow(sd, 0.04);
    
    vec3 col = vec3(0);
    col += pow(hori, 200.f) * vec3(1.0, 0.7,  0.5) * 3.f;
    col += pow(hori, 25.f) * vec3(1.0, 0.5,  0.25) * 0.3;
    col += pow(hori, 7.f) * vec3(1.0, 0.4, 0.25) * 0.8;
    
    return col;
}

//=========================

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
    int materialID;
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

float smoothUnion( float d1, float d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

float terrianSDF(vec3 queryPos)
{
  float noise = fbm(vectorFBM(queryPos.xz, 0.4, 8, 10.0), 0.5, 4) + 1.8;
  noise += fbm(queryPos.xz, 0.5, 10) * 0.2;
  float height = queryPos.y - noise;

  return height;
}

float waterSDF(vec3 queryPos, float height)
{
  float noise = sin(queryPos.x * 1.2 * (u_Time / 200.0)) * 0.1;
  height = queryPos.y - height - (noise * 0.2);

  return height;
}

//=========================
const float waterHeight = 2.15;

float sdfTerrainUnion(float t1, float t2, out int matID) {
  if (t1 < t2) {
    matID = 0;
    return t1;
  } else {
    matID = 1;
    return t2;
  }
}

float sceneSDF(vec3 queryPos, out int matID) 
{
    float ground = terrianSDF(queryPos);
    float plane = waterSDF(queryPos, waterHeight);
    float t = sdfTerrainUnion(ground, plane, matID);

    return t;
}

float sceneSDF(vec3 queryPos) 
{
    float ground = terrianSDF(queryPos);
    float plane = waterSDF(queryPos, waterHeight);

    int matID;
    return sdfTerrainUnion(ground, plane, matID);
}

Ray getRay(vec2 uv) {
    Ray ray;
    // vec3 EYE = u_Eye;
    // vec3 REF = u_Ref;
    
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
    int matID;
    Intersection intersection;
    
    vec3 queryPoint = ray.origin;
    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        float distanceToSurface = sceneSDF(queryPoint, matID);
        
        if (distanceToSurface < EPSILON)
        {
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);
            intersection.materialID = matID;
            
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
    backgroundColor = SUN_KEY_LIGHT;
    
    vec3 albedo = getColor(intersection.materialID, intersection.position);
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
        color = pow(color, vec3(1. / 2.2));
    }
    else
    {
        color = vec3(0.0);
    }
        color = applyFog(color, intersection.distance, getRay(uv).direction, lights[0].dir);
        color += scatter(getRay(uv).origin, getRay(uv).direction, lights[0].dir);
        return color;
}

void main()
{
  vec2 uv = (gl_FragCoord.xy/u_Dimensions.xy) * 2.0f - vec2(1.0f);

  vec3 col = getSceneColor(uv);

  out_Col = vec4(col,1.0);
}
