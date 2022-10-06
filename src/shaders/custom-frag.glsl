#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

#define MAX_RAY_STEPS 512
#define EPSILON 1e-2

// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
// #define SUN_KEY_LIGHT vec3(0.6, 0.7, 0.5) * 1.5
#define SUN_KEY_LIGHT vec3(0.5 * sin(u_Time * 0.003) + 0.4, 0.5 * sin(u_Time * 0.003) + 0.4, 0.5 * sin(u_Time * 0.003) + 0.4) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.5, 0.2, 0.7) * 0.2
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

float noise1D( vec2 p ) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) *
                 43758.5453);
}

float interpNoise2D(float x, float y) {
    float intX = float(floor(x));
    float fractX = fract(x);
    float intY = float(floor(y));
    float fractY = fract(y);

    float v1 = noise1D(vec2(intX, intY));
    float v2 = noise1D(vec2(intX + 1.0, intY));
    float v3 = noise1D(vec2(intX, intY + 1.0));
    float v4 = noise1D(vec2(intX + 1.0, intY + 1.0));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}

float fbm(float x, float y) {
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.f;
    float amp = 0.5f;
    for(int i = 1; i <= octaves; i++) {
        total += interpNoise2D(x * freq,
                               y * freq) * amp;

        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}

float bias(float t, float b) {
    return (t / ((((1.0/b) - 2.0)*(1.0 - t))+1.0));
}

float gain(float t, float g) {
    if (t < 0.5f) {
		return bias(1.0f - g, 2.0f * t) / 2.0f;
	}
	else {
		return 1.0 - bias(1.0f - g, 2.0 - 2.0 * t) / 2.0f;
	}
}

float tri_wave(float x, float freq, float amp) {
    return abs(mod(x * freq, amp) - (0.5 * amp));
}

// sphereSDF
float sphereSDF(vec3 query_position, vec3 position, float radius)
{
  return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
  return queryPos.y - height;
    
}

float mountainSDF(vec3 queryPos, float height, out float fb)
{
  float f = 8.0f * fbm(queryPos.x * 0.1f, queryPos.z * 0.1f);
  fb = f;
  return queryPos.y - (height + f);
    
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

// build scene
float sceneSDF(vec3 queryPos, out int obj) 
{
  float fb;
  float lake = planeSDF(queryPos, 3.0 + tri_wave(sin(0.002 * u_Time), 0.5, 0.5));
  float mountain = mountainSDF(queryPos, 0.0, fb);
  float circle = sphereSDF(queryPos, vec3(1.0, 5.0, 10.0), 1.0);

  float terrain = smoothUnion(mountain, lake, 0.1);

  // calculate mountain color
  fb = fb * gain(fb, 10.0);
  obj = 0;
  if (fb > 4.0) {
    obj = 1; // snow
  } else if (fb < 2.5) {
    obj = 2; // water
  }

  return terrain;
}


Ray getRay(vec2 uv) {
    Ray ray;
    
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = -normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = -normalize(cross(H, u_Eye - u_Ref));
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
  int hitobj;

  vec3 queryPoint = ray.origin;
  for (int i=0; i < MAX_RAY_STEPS; ++i)
    {

    float distanceToSurface = sceneSDF(queryPoint, hitobj);
    
    intersection.material_id = 0;
    if (hitobj == 1) {
      intersection.material_id = 1; // snow
    } else if (hitobj == 2) {
      intersection.material_id = 2; // water
    }

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
  int dummyVar;
  return normalize(vec3(
    sceneSDF(vec3(p.x + EPSILON, p.y, p.z), dummyVar) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z), dummyVar),
    sceneSDF(vec3(p.x, p.y + EPSILON, p.z), dummyVar) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z), dummyVar),
    sceneSDF(vec3(p.x, p.y, p.z  + EPSILON), dummyVar) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON), dummyVar)
  ));
}

vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    lights[0] = DirectionalLight(normalize(vec3(15.0, 10.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    backgroundColor = SUN_KEY_LIGHT;
    
    vec3 albedo = vec3(0.3,0.5,0.3);
    if (intersection.material_id == 2) {
      albedo = vec3(0.0, 0.2, 0.9);
    } else if (intersection.material_id == 1) {
      albedo = vec3(1.0, 1.0, 1.0);
    }
      
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
      color = vec3(0.1 * sin(u_Time * 0.003 - 0.01) + 0.05, 0.2 * sin(u_Time * 0.003 - 0.01) + 0.1, 0.6 * sin(u_Time * 0.003 - 0.01) + 0.5);
      // color = vec3(0.5, 0.7, 0.9);
      
    }
      color = pow(color, vec3(1. / 2.2));
      return color;
}

void main() {

  // Normalized pixel coordinates (from 0 to 1)
  vec2 uv = gl_FragCoord.xy / u_Dimensions.xy;
  
  // Make symmetric [-1, 1]
    uv = uv * 2.0 - 1.0;

  // Time varying pixel color
  vec3 col = getSceneColor(uv);
  
  out_Col = vec4(col,1.0);
}
