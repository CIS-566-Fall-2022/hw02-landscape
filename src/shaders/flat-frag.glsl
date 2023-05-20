#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

uniform mat4 u_ViewProj;

#define STEPSIZE 0.01
#define MIN_T 0.001
#define MAX_T 5.0
#define IOR 1.3
const int MAXSTEPS = 1000;
#define EPS 0.001
const float DISCRETIZE_NUM = 4.0;

const float SPHERE_RADIUS = 1.5;
const float TERRAIN_FREQ = 2.0;
const float TERRAIN_AMP = 0.6;

const vec3 SKYCOLOR = vec3(0.47, 0.66, 0.82);
const vec3 CLOUDCOLOR = vec3(1.0);
const float CLOUD_HEIGHT = 0.4;
const float CLOUD_THICKNESS = 0.3;
const float CLOUD_SPEED = 0.005;

const vec3 KEYLIGHT_POS = vec3(15, 15, 10);
const vec3 KEYLIGHT = vec3(1.0, 1.0, 0.9) * 1.0;
const vec3 FILLLIGHT_POS = vec3(0, 5, 0);
const vec3 FILLLIGHT = vec3(0.47, 0.66, 0.82) * 0.7;
const vec3 BACKLIGHT_POS = vec3(0, -5, 0);
const vec3 BACKLIGHT = vec3(1.0, 1.0, 0.9) * 0.3;

in vec2 fs_Pos;
in vec4 fs_LightVec;  
out vec4 out_Col;


float ease_in_quadratic(float t) 
{
    return t * t;
}

float bias(float b, float t) 
{
    return pow(t, log(b) / log(0.5));
}

float gain(float g, float t) 
{
    if (t < 0.5)
        return bias(1.0-g, 2.0*t)/2.0;
    else
        return 1.0 - bias(1.0-g, 2.0 - 2.0*t)/2.0;
}

float impulse(float k, float x)
{
    float h = k*x;
    return h * exp(1.0-h);
}

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float hash1( vec2 p )
{
    p  = 50.0*fract( p*0.3183099 );
    return fract( p.x*p.y*(p.x+p.y) );
}

float hash1( float n )
{
    return fract( n*17.0*fract( n*0.3183099 ) );
}

// Hash functions are taken from IQ's shadertoy examples
float hash2(in vec2 st) {
    return fract(sin(dot(st.xy,
                  vec2(12.9898,78.233)))
                 * 43758.5453123);
}

float hash3(vec3 p)
{
  p = fract( p*0.3183099+.1 );
  p *= 20.0;
  return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float trilinear(float a, float b, float c, float d, 
                float e, float f, float g, float h, vec3 u)
{
    return mix(mix(mix(a, b, u.x), mix(c, d, u.x), u.y), 
                mix(mix(e, f, u.x), mix(g, h, u.x), u.y), u.z);
}

float bilinear(float a, float b, float c, float d, vec2 u)
{
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 cubic2(vec2 t)
{
    return t*t*(3.0-2.0*t);
}

vec3 cubic3(vec3 t)
{
    return t*t*(3.0-2.0*t);
}

vec2 quintic2(vec2 t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

vec3 quintic3(vec3 t)
{
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// float grad(vec3 2, vec3 2, vec2 inc)
// {
//     return dot(hash3(i + inc), f - inc);
// }

float noise3( in vec3 x )
{
    vec3 p = floor(x);
    vec3 u = fract(x);
    u = cubic3(u);

    float n = p.x + 317.0*p.y + 157.0*p.z;
    
    float a = hash1(n+0.0);
    float b = hash1(n+1.0);
    float c = hash1(n+317.0);
    float d = hash1(n+318.0);
    float e = hash1(n+157.0);
	  float f = hash1(n+158.0);
    float g = hash1(n+474.0);
    float h = hash1(n+475.0);

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z);
}

float noise2( in vec2 x )
{
    vec2 i = floor(x);
    vec2 u = fract(x);
    u = cubic2(u);

    float a = hash2(i + vec2(0,0));
    float b = hash2(i + vec2(1,0));
    float c = hash2(i + vec2(0,1));
    float d = hash2(i + vec2(1,1));

    return bilinear(a, b, c, d, u);
}

float fbm3(in vec3 pos, const int octaves)
{
    float value = 0.f;
    float amp = 0.5f;
    float freq = 0.f;

    for (int i = 0; i < octaves; i++)
    {
        value += amp * noise3(pos);
        pos *= 2.0f;
        amp *= 0.5f;
    }

    return value;
}

float fbm2(in vec2 pos)
{
    float total = 0.f;
    float amplitudeSum = 0.f;

    for (int i = 0; i < 10; i++)
    {
        float frequency = pow(2.0f, float(i));
        float amplitude = pow(0.4f, float(i));
        
        amplitudeSum += amplitude;

        total += amplitude*noise2(frequency*pos*1.0);
    }

    return total/amplitudeSum;
}

float sdBox(vec3 p, vec3 b)
{
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdRoundBox( vec3 p, vec3 b, float r )
{
  vec3 q = abs(p) - b;
  return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdBBox(vec3 p)
{
    return sdBox(p, vec3(2.0, 2.0, 2.0));
}

float sdSphere( vec3 p, float s )
{
  return length(p)-s;
}

float sdCloud( vec3 p, int octaves )
{
  float d = abs(p.y - CLOUD_HEIGHT) - CLOUD_THICKNESS;
  return -d + CLOUD_THICKNESS*fbm3((p + CLOUD_SPEED * u_Time * vec3(1.0, 0.0, 1.0))*3.0, octaves);
}

float sdCloud( vec3 p )
{
  return sdCloud(p, 8);
}

vec3 gradCloud( const vec3 p )
{
  const int oct = 4;
  const vec3 dx = vec3(EPS, 0, 0);
  const vec3 dy = vec3(0, EPS, 0);
  const vec3 dz = vec3(0, 0, EPS);

  return vec3(sdCloud(p + dx, oct) - sdCloud(p - dx, oct),
              sdCloud(p + dy, oct) - sdCloud(p - dy, oct),
              sdCloud(p + dz, oct) - sdCloud(p - dz, oct));
}

float sdHeight( in vec3 p )
{
  float h = TERRAIN_AMP*fbm2(TERRAIN_FREQ*p.xz);
  h = map(h, 0.0, 1.0, -0.8*SPHERE_RADIUS, 0.8*SPHERE_RADIUS);
  return p.y - h;
}

float discr( float x )
{
  float w = 1.0/DISCRETIZE_NUM;
  return floor(x/w)*w;
}

float shadowP (vec3 pos, in vec3 dir, float k)
{
  pos += dir * 0.1;
  float res = 1.0;
  for (int i = 0; i < 50; ++i)
  {
    float d = sdHeight( pos );
    if (d < EPS)
      return 0.0;

    // soft shadow
    res = min(res, k*d/(float(i)*STEPSIZE));
    pos += dir * STEPSIZE;
  }
  return res;
}

vec3 shadeToon( vec3 pos, vec3 normal, vec3 albedo )
{
  vec3 n = normalize(normal);
  // Calculate the diffuse term for Lambert shading

  vec3 col = albedo * 
            KEYLIGHT * 
            discr(max(0.0, dot(n, normalize(KEYLIGHT_POS - pos))));
  col += albedo * FILLLIGHT * discr(max(0.0, dot(n, normalize(FILLLIGHT_POS - pos))));

  return col;
}

vec3 shadeLambert( vec3 pos, vec3 normal, vec3 albedo )
{
  vec3 n = normalize(normal);
  // Calculate the diffuse term for Lambert shading

  vec3 col = albedo * 
            KEYLIGHT * 
            max(0.0, dot(n, normalize(KEYLIGHT_POS - pos)));
  col += albedo * FILLLIGHT * clamp(dot(n, normalize(FILLLIGHT_POS - pos)), 0.0, 1.0);
  col += albedo * BACKLIGHT * clamp(dot(n, normalize(BACKLIGHT_POS - pos)), 0.0, 1.0);

  return col;
}

vec3 skyColor( vec2 uv )
{
  float t = map(sqrt(uv.x*uv.x + uv.y*uv.y), 0.0, 1.414, 0.0, 1.0);
  return mix(SKYCOLOR, vec3(0.0), gain(0.8, t));
}

vec3 getTerrainNormal( const vec3 p )
{
  const vec3 dx = vec3(EPS, 0, 0);
  const vec3 dz = vec3(0, 0, EPS);
  return normalize(vec3(sdHeight(p + dx) - sdHeight(p - dx), 
                      2.0*EPS,
                      sdHeight(p + dz) - sdHeight(p - dz)));
}

vec3 getTerrainShading( vec3 pos, vec3 n )
{
  vec3 s = normalize(KEYLIGHT_POS - pos);

  // TODO: Use line intersection to find q exactly
  vec3 q = pos + s * (CLOUD_HEIGHT - pos.y) * 2.0;

  vec3 col = KEYLIGHT * 
             max(0.0, dot(n, s)) *
             shadowP(pos, s, 2.0) * smoothstep(-0.3, 0.3, sdCloud(q));
            // shadowP(pos, normalize(KEYLIGHT_POS - pos));
  col += FILLLIGHT * max(0.0, dot(n, normalize(FILLLIGHT_POS - pos)));
  col += BACKLIGHT * max(0.0, dot(n, normalize(BACKLIGHT_POS - pos)));
  return col;
}

vec3 getTerrainMaterial( vec3 p, vec3 n )
{
  vec3 col = vec3(0.21, 0.25, 0.20);  // ground
  col = mix(col, /* grass */ vec3(0.90,0.58,0.38), smoothstep(0.2, 0.8, n.y));
  col = mix(col, vec3(0.94, 0.95, 0.93), smoothstep(-0.4, 0.0, p.y));

  return col;
}

vec3 applyFog( vec3 col, float d )
{
  return mix(vec3(0.80), col, exp(-0.2*d));
}

bool hitBSphere( inout vec3 p, in vec3 dir)
{
  for (int i = 0; i < 50; i++)
  {
    float d = sdSphere(p, SPHERE_RADIUS);
    p += dir * d;
    if (d < EPS) return true;  // P should be right on the sphere
  }
  return false;
}

vec3 hitTerrain( inout vec3 p, in vec3 dir)
{
  const float threshold = 0.95;

  vec3 color = vec3(0.0);

  float dt = STEPSIZE;
  float lh = 0.0;
  float ly = 0.0;
  float a = 0.0;
  float t = MIN_T;
  
  p += dt * dir;

  for (; t < MAX_T; t += dt)
  {

      float cloudDensity = sdCloud(p);
      cloudDensity = smoothstep(0.3, 0.4, cloudDensity);

      if (cloudDensity > 0.0)
      {
        // TODO: Figure out a better way to compute gradient
        vec3 grad = normalize(vec3(0.0, 1.0, 0.0)+2.0*fbm3(p, 4));
        vec3 s = normalize(KEYLIGHT_POS - p);
        vec3 s2 = normalize(FILLLIGHT_POS - p);
        vec3 s3 = normalize(BACKLIGHT_POS - p);

        // float ld = sdCloud(p + 5.0*STEPSIZE*s);
        // float shadow = 1.0 - smoothstep(-1.0, 1.0, ld);
        // shadow *= 1.5;

        vec3 col = vec3(0.0);
        col += 0.5*clamp(0.3+0.7*dot(grad, s),  0.0, 1.0);
        col += 0.3*clamp(0.3+0.7*dot(grad, s2), 0.0, 1.0);
        col += 0.2*clamp(0.3+0.7*dot(grad, s3), 0.0, 1.0);


        color += (1.0 - a) * cloudDensity * col;
        a += (1.0 - a) * cloudDensity * 0.5;
      }
    
      float d = sdHeight(p);

      if (d < EPS)
      {
          p -= dir * dt; // step back one
          p += dir * dt*(lh-ly)/(-ly+d+lh); // step to interpolated point

          // Calculate normal
          vec3 n = getTerrainNormal(p);

          color += getTerrainShading(p, n) * getTerrainMaterial(p, n);

          break;
      }

      float r = sdSphere(p, SPHERE_RADIUS);

      // Checks if the ray hits the bounding box from the inside
      if (r > 0.0)
      {
          p -= dir*r;
          dir = refract(dir, normalize(p), IOR/1.0);
          vec4 uv = u_ViewProj*vec4(p + dir*0.5, 1.0);

          color += skyColor(vec2(uv.x, uv.y));

          break;
      }

      lh = p.y - d;
      ly = p.y;

      dt = STEPSIZE + 0.01*t;
      p += dir * dt;
  }

  return applyFog(clamp(color, 0.0, 1.0), t);
}

void main() {

  vec3 eye = u_Eye;
  vec3 forward = normalize(u_Ref - u_Eye);
  vec3 up = u_Up;
  vec3 right = normalize(cross(forward,up));

  float f = 0.5 * distance(u_Eye, u_Ref);
  float u = gl_FragCoord.x * 2.0 / u_Dimensions.x - 1.0;
  float v = gl_FragCoord.y * 2.0 / u_Dimensions.y - 1.0;

  float aspectRatio = u_Dimensions.x / u_Dimensions.y;
  right *= aspectRatio;

  // ray's world position
  vec3 pos = eye + right * u + up * v + forward * f;
  // ray's direction
  vec3 dir = normalize(pos - eye);

  vec3 col = vec3(0.);
  if (hitBSphere(pos, dir))
  {
    if(sdHeight(pos) < EPS)
      col = shadeLambert(pos, normalize(pos), vec3(0.3));
    else
    {
      dir = refract(dir, normalize(pos), 1.0/IOR);
      col = hitTerrain(pos, dir);
    }
  }
  else 
  {
    col = skyColor(vec2(u, v));
  }

  out_Col = vec4(col, 1.0);
}
