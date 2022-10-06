#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;


in vec2 fs_Pos;
out vec4 out_Col;

///////////////////////////////
//noise stuff//
float hash(vec3 p)  // replace this by something better
{
    p  = 50.0*fract( p*0.3183099 + vec3(0.71,0.113,0.419));
    return -1.0+2.0*fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float turbulence( vec3 p ) {

  float w = 100.0;
  float t = -.5;

  for (float f = 1.0 ; f <= 10.0 ; f++ ){
    float power = pow( 2.0, f );
    t += abs( hash( vec3( power * p ) ) / power );
  }

  return t;

}


// return value noise (in x) and its derivatives (in yzw)
vec4 noised(vec3 x )
{
    vec3 i = floor(x);
    vec3 w = fract(x);

    // quintic interpolation
    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-2.0)+1.0);   
    
    float a = hash(i+vec3(0.0,0.0,0.0));
    float b = hash(i+vec3(1.0,0.0,0.0));
    float c = hash(i+vec3(0.0,1.0,0.0));
    float d = hash(i+vec3(1.0,1.0,0.0));
    float e = hash(i+vec3(0.0,0.0,1.0));
	float f = hash(i+vec3(1.0,0.0,1.0));
    float g = hash(i+vec3(0.0,1.0,1.0));
    float h = hash(i+vec3(1.0,1.0,1.0));
	
    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return vec4( k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z, 
                 du * vec3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                            k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                            k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}

//#define OCTAVES u_Octaves
float fbm (vec3 v) {
    int oct = 4;
    // Initial values
    float value = 0.0;
    float amplitude = .5;
    float frequency = 0.;

    // Loop of octaves
    for (int i = 0; i < oct; i++) {
        value += amplitude * abs(noised(v).x);
        v *= 2.;
        amplitude *= .5;
    }
    return value;
}

///////////////////////////////////////////////////////////////////////////////////////
const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);
const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;

//3 point lighting system
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
    query_position = mod(query_position, 0.2);
    return length(query_position - position) - radius;
}

//generates a plane at y = height
//returns the diffence in y positions
//queryPos
float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

float terrainSDF(vec3 queryPos)
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

//idea have sdf objects be a vec4: xyz = color, w = distance

//all sdfs go here
float sceneSDF(vec3 queryPos) 
{
    float plane = planeSDF(queryPos, 0.0);
    float waves = terrainSDF(queryPos + 0.5*fbm(queryPos));
    float sphere = sphereSDF(queryPos, vec3(0., 2., -2.), 1.);
    float composite = plane + waves;
    composite = min(composite, sphere); //to compose multiple things take the min
    return composite;
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


vec4 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    float y = intersection.position.y;
    // vec3 _color;
    // vec3 c_low = vec3(1., 0., 0.);
    // vec3 c_med = vec3(0., 1., 0.);
    // vec3 c_high = vec3(0., 0., 1.);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 SUN_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    
    // lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
    //                              SUN_KEY_LIGHT);
    // lights[1] = DirectionalLight(vec3(0., 1., 0.),
    //                              SKY_FILL_LIGHT);
    // lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
    //                              SUN_AMBIENT_LIGHT);
    backgroundColor = SUN_KEY_LIGHT;
    
    vec3 albedo = vec3(0.5);
    vec3 n = estimateNormal(intersection.position);
        
    // vec3 color = albedo *
    //              lights[0].color *
    //              max(0.0, dot(n, lights[0].dir));
    vec4 color = vec4(albedo *
                 lights[0].color *
                 max(0.0, dot(n, lights[0].dir)), 1.);

    bool scene = false;
    
    if (intersection.distance > 0.0)
    { 
      scene = true;
        for(int i = 1; i < 3; ++i) { // key, fill and ambient lights
            // color += albedo *
            //          lights[i].color *
            //          max(0.0, dot(n, lights[i].dir));
            color += vec4(albedo *
                     lights[i].color *
                     max(0.0, dot(n, lights[i].dir)), 1.);
        }
    }
    else
    {
        // color = vec3(0.5, 0.7, 0.9); //background color
        color = vec4(0.5, 0.7, 0.9, -1.); //background color
    }
        if (scene){
          // color = c_low;
          color.w = 0.5;
        }
        
        // color = pow(color, vec3(1. / 2.2));
        color = pow(color, vec4(1. / 2.2));
        return color;
}

float rand3D(vec3 co){
    return fract(sin(dot(co.xyz ,vec3(12.9898,78.233,144.7272))) * 43758.5453);
}

void main() {
  //get uv coords in -1,1 domain for x and y
  vec2 uv = (vec2(gl_FragCoord.xy) /u_Dimensions) * 2. - 1.;

  vec4 col = getSceneColor(uv);
  float alpha = 1.;
  if (col[3] > 0.){ //not background
    // alpha = smoothstep(.9, 1., rand3D(col.xyz));
    alpha = .9;
  }
  col.w = alpha;
  vec4 inv_col = vec4(1.) - col;
  inv_col.w = 1.;
  //VVVvary (pick npise from color then inv_col) with time mod later to make it sparkle VVV
  float noise_col = rand3D(vec3(col));
  float noise_col_inv = rand3D(vec3(inv_col));
  vec4 output_color = vec4(1.);
  if (noise_col < .5){
    output_color = col;
  } else {
    output_color = inv_col;
  }
  // if (col == vec3(1., 0., 0.)){
  //   alpha = 0.7;
  // }
  out_Col = output_color;
}

//idea
//have three terrains, and more mountainous
//low, med, hi each have 2 colors in their respective areas
//the two colors will use random noise and if noise <0.5 it will be color 1 else color 2
//let's test this out.
