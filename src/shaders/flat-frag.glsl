#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const int MAX_RAY_STEPS = 140;
const float FOV = 45.0;
const float EPSILON = 0.001;

const vec3 EYE = vec3(0.0, 10.0, 0.0);
const vec3 REF = vec3(0.0, 6.0, 40.0);

const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);

#define SUN_KEY_LIGHT vec3(0.4, 0.4, 0.4) * 1.5


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

struct SdfInformation
{
  float distance;
  int material_id;
};

struct DirectionalLight
{
    vec3 dir;
    vec3 color;
};

////////////////////-------------- UTILITIES --------------////////////////////
vec4 vec3ToVec4(vec3 vec, float f) {
    return vec4(vec[0], vec[1], vec[2], f);
}

vec3 vec4ToVec3(vec4 vec) {
    return vec3(vec[0], vec[1], vec[2]);
}

float remap(float val, float oldmin, float oldmax, float newmin, float newmax) {
    float normalized = (val - oldmin)/(oldmax - oldmin);
    return (normalized * (newmax - newmin)) + newmin;
}

////////////////////-------------- TOOLBOX FUNCTIONS --------------////////////////////
float getBias(float time, float bias)
{
  return (time / ((((1.0/bias) - 2.0)*(1.0 - time))+1.0));
}

float getGain(float time, float gain)
{
  if(time < 0.5)
    return getBias(time * 2.0,gain)/2.0;
  else
    return getBias(time * 2.0 - 1.0,1.0 - gain)/2.0 + 0.5;
}

float easeInOutQuad(float x) {
    return x < 0.5 ? 2.0 * x * x : 1.0 - pow(-2.0 * x + 2.0, 2.0) / 2.0;
}

////////////////////-------------- NOISE FUNCTIONS --------------////////////////////
float noise3D( vec3 p ) {
    return fract(sin(dot(p, vec3(127.1f, 311.7f, 213.f)))
                 * 43758.5453f);
}

float interpNoise3D(float x, float y, float z) {
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);

    float v1 = noise3D(vec3(intX, intY, intZ));
    float v2 = noise3D(vec3(intX+1, intY, intZ));
    float v3 = noise3D(vec3(intX, intY+1, intZ));
    float v4 = noise3D(vec3(intX+1, intY+1, intZ));
    float v5 = noise3D(vec3(intX, intY, intZ+1));
    float v6 = noise3D(vec3(intX+1, intY, intZ+1));
    float v7 = noise3D(vec3(intX, intY+1, intZ+1));
    float v8 = noise3D(vec3(intX+1, intY+1, intZ+1));
    
    float i1 = mix(v1, v2, easeInOutQuad(fractX));
    float i2 = mix(v3, v4, easeInOutQuad(fractX));
    float i3 = mix(v5, v6, easeInOutQuad(fractX));
    float i4 = mix(v7, v8, easeInOutQuad(fractX));

    float m1 = mix(i1, i2, easeInOutQuad(fractY));
    float m2 = mix(i3, i4, easeInOutQuad(fractY));

    return mix(m1, m2, easeInOutQuad(fractZ));
}

float fbm(float x, float y, float z, float freq, float amp, int octaves, float persistence) {
    float total = 0.0;

    for(int i = 1; i <= octaves; i++) {
        total += interpNoise3D(x * freq,
                               y * freq,
                               z * freq) * amp;

        freq *= 2.0;
        amp *= persistence;
    }
    return total;
}

/////////////////////////////////////////////////////////////////

SdfInformation sphereSDF(vec3 query_position, vec3 position, float radius)
{
    SdfInformation sdfInformation;
    sdfInformation.distance = length(query_position - position) - radius;
    sdfInformation.material_id = -1;
    
    return sdfInformation;
}
SdfInformation torusSDF( vec3 p, vec2 t )
{
  vec2 q = vec2(length(p.xz)-t.x,p.y);

  SdfInformation sdfInformation;
  sdfInformation.distance = length(q)-t.y;
  sdfInformation.material_id = -1;

  return sdfInformation;
}

// capped cone from IQ
SdfInformation cappedConeSDF( vec3 p, float h, float r1, float r2 )
{
  vec2 q = vec2( length(p.xz), p.y );
  vec2 k1 = vec2(r2,h);
  vec2 k2 = vec2(r2-r1,2.0*h);
  vec2 ca = vec2(q.x-min(q.x,(q.y<0.0)?r1:r2), abs(q.y)-h);
  vec2 cb = q - k1 + k2*clamp( dot(k1-q,k2)/dot(k2,k2), 0.0, 1.0 );
  float s = (cb.x<0.0 && ca.y<0.0) ? -1.0 : 1.0;

  SdfInformation sdfInformation;
  sdfInformation.distance = s*sqrt( min(dot(ca,ca),dot(cb,cb)) );
  sdfInformation.material_id = -1;

  return sdfInformation;
}

SdfInformation coneSDF( vec3 p, vec2 c, float h )
{
  float q = length(p.xz);

  SdfInformation sdfInformation;
  sdfInformation.distance = max(dot(c.xy,vec2(q,p.y)),-h-p.y);
  sdfInformation.material_id = -1;

  return sdfInformation;
}

SdfInformation planeYSDF(vec3 queryPos, float height, float drxn)
{
    SdfInformation sdfInformation;
    sdfInformation.distance = drxn*(queryPos.y - height);
    sdfInformation.material_id = -1;
    
    return sdfInformation;
}
SdfInformation planeZSDF(vec3 queryPos, float height, float drxn) // drxn = -1 or +1
{
    SdfInformation sdfInformation;
    sdfInformation.distance = drxn*(queryPos.z - height);
    sdfInformation.material_id = -1;
    
    return sdfInformation;
}
SdfInformation capsuleSDF( vec3 queryPos, vec3 a, vec3 b, float r )
{
  vec3 pa = queryPos - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );

  SdfInformation sdfInformation;
  sdfInformation.distance = length( pa - ba*h ) - r;
  sdfInformation.material_id = -1;

  return sdfInformation;
}

SdfInformation smoothUnion(SdfInformation d1, SdfInformation d2, float k ) {
    float h = clamp( 0.5 + 0.5*(d2.distance-d1.distance)/k, 0.0, 1.0 );
    float newDistance = mix( d2.distance, d1.distance, h ) - k*h*(1.0-h);

    if(d1.distance < d2.distance) {
      d1.distance = newDistance;
      return d1;
    } else {
      d2.distance = newDistance;
      return d2;
    }
}


float smoothSubtraction( float d1, float d2, float k ) 
{
    float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
    return mix( d2, -d1, h ) + k*h*(1.0-h); 
}

SdfInformation smoothIntersection( SdfInformation d1, SdfInformation d2, float k )
{
    float h = clamp( 0.5 - 0.5*(d2.distance-d1.distance)/k, 0.0, 1.0 );
    float newDistance = mix( d2.distance, d1.distance, h ) + k*h*(1.0-h);

    d1.distance = newDistance; // material of first is returned

    return d1;
}

float getWaveDisp(float x, float noise){
  float waterDisp = 0.8 * abs(sin(x * 10.0));
  waterDisp += 0.5 * sin(x * 4.5) + noise * 3.0; 
  waterDisp += 40.0;
  return waterDisp;
}

SdfInformation waveSDF(vec3 queryPos, float height)
{
    vec3 warpedCoords = queryPos * 0.1;
    float noise = fbm(queryPos.x, queryPos.y, queryPos.z + u_Time / 2.0, 0.03, 1.0, 2, 0.5);
    warpedCoords.x = warpedCoords.x + noise;

    float waterDisp = getWaveDisp(warpedCoords.x + u_Time / 80.0, noise);

    float distance = queryPos.y - height + waterDisp;

    SdfInformation waveSdf;
    waveSdf.distance = distance;
    waveSdf.material_id = 0;

    SdfInformation plane1Sdf = planeZSDF(queryPos, 153.0, 1.0);
    SdfInformation plane2Sdf = planeZSDF(queryPos, 150.0, -1.0);

    SdfInformation returnSdf = smoothIntersection(plane1Sdf, waveSdf, 2.0);
    returnSdf = smoothIntersection(plane2Sdf, returnSdf, 2.0);
    returnSdf.material_id = 0;
    return returnSdf;
}

SdfInformation ghibliWaterSDF(vec3 queryPos, float height)
{
    vec3 warpedCoords = queryPos * 0.5;
    warpedCoords.z *= 6.0;

    SdfInformation sdf1;
    float waterDisp1 = fbm(warpedCoords.x + u_Time/40.0, warpedCoords.y + u_Time/100.0, warpedCoords.z, 0.1, 3.0, 6, 0.4);
    sdf1.distance = queryPos.y - height + waterDisp1;
    sdf1.material_id = 0;

    SdfInformation sdf2;
    float waterDisp2 = fbm(warpedCoords.x + u_Time/40.0, warpedCoords.y + u_Time/100.0 + 0.001, warpedCoords.z, 0.1, 3.0, 6, 0.4);
    sdf2.distance = queryPos.y - height + waterDisp2 + 0.0001;
    sdf2.material_id = 1;

    SdfInformation sdf3;
    float waterDisp3 = fbm(warpedCoords.x + u_Time/40.0, warpedCoords.y + u_Time/100.0 + 0.002, warpedCoords.z, 0.1, 3.0, 6, 0.4);
    sdf3.distance = queryPos.y - height + waterDisp3 + 0.0004;
    sdf3.material_id = 2;

    SdfInformation returnSdf = smoothUnion(sdf1, sdf2, 0.0);
    returnSdf = smoothUnion(returnSdf, sdf3, 0.0);

    // make water behind graphic style waves invisible
    if(queryPos.z > 150.0) {
      returnSdf.distance = 1.0;
    }
    return returnSdf;
}

SdfInformation landSdf(vec3 queryPos)
{
  vec3 warpedPos = queryPos;
  warpedPos.x /= 3.5;
  warpedPos.z /= 3.0;
  warpedPos.y += warpedPos.x / 2.0; // smooths right edge down better

  warpedPos.y += 3.0;
  warpedPos.x -= 3.0;

  warpedPos.x += fbm(0.0, queryPos.y, queryPos.z, 0.1, 10.0, 3, 0.3);
  warpedPos.y += fbm(queryPos.x, 0.0, queryPos.z, 0.05, 2.0, 2, 0.3);

  SdfInformation sphere = sphereSDF(warpedPos, vec3(-5.0, -10.0, 40.0), 20.0);
  sphere.material_id = 3;
  return sphere;
}

SdfInformation landLargeProxySdf(vec3 queryPos)
{
  vec3 warpedPos = queryPos;
  warpedPos.x /= 3.5;
  warpedPos.z /= 3.0;
  warpedPos.y += warpedPos.x / 0.8; // smooths right edge down better

  warpedPos.y += 3.0;
  warpedPos.x -= 3.0;

  warpedPos.x -= 0.5;
  warpedPos.y -= 3.0;
  warpedPos.z -= 0.5;


  warpedPos.x += fbm(0.0, queryPos.y, queryPos.z, 0.1, 10.0, 3, 0.3);
  warpedPos.y += fbm(queryPos.x, 0.0, queryPos.z, 0.05, 2.0, 2, 0.3);

  SdfInformation sphere = sphereSDF(warpedPos, vec3(-5.0, -10.0, 40.0), 20.0);
  sphere.material_id = 3;
  return sphere;
}

SdfInformation cloudSdf(vec3 queryPos, vec3 center, float stretch) {
  vec3 warpedCoords = queryPos;
  warpedCoords.x /= stretch;
  warpedCoords.x = warpedCoords.x + fbm(queryPos.x, queryPos.y, queryPos.z, 0.08, 5.0, 2, 0.5);
  warpedCoords.y = warpedCoords.y + fbm(queryPos.x, queryPos.y, queryPos.z, 0.1, 3.0, 2, 0.5);

  SdfInformation sphere1 = sphereSDF(warpedCoords, center - vec3(2.0, 0.0, 0.0), 5.0);
  SdfInformation sphere2 = sphereSDF(warpedCoords, center - vec3(7.0, 1.0, 0.0), 2.5);
  SdfInformation sphere3 = sphereSDF(warpedCoords, center + vec3(4.0, -3.0, 0.0), 4.0);
  SdfInformation sphere4 = sphereSDF(warpedCoords, center + vec3(9.0, 0.0, 0.0), 6.0);
  SdfInformation sphere5 = sphereSDF(warpedCoords, center + vec3(17.0, -1.0, 0.0), 4.0);
  SdfInformation sphere6 = sphereSDF(warpedCoords, center + vec3(13.0, 3.0, 0.0), 5.0);
  SdfInformation sphere7 = sphereSDF(warpedCoords, center + vec3(4.0, 5.0, 0.0), 6.0);
  SdfInformation sphere8 = sphereSDF(warpedCoords, center + vec3(21.0, -1.0, 0.0), 2.0);

  SdfInformation union1 = smoothUnion(sphere1, sphere2, 1.0);
  SdfInformation union2 = smoothUnion(sphere3, sphere4, 1.0);
  SdfInformation union3 = smoothUnion(sphere5, sphere6, 1.0);
  SdfInformation union4 = smoothUnion(sphere7, sphere8, 1.0);

  SdfInformation unionA = smoothUnion(union1, union2, 1.0);
  SdfInformation unionB = smoothUnion(union3, union4, 1.0);

  SdfInformation finalClouds = smoothUnion(unionA, unionB, 1.0);
  finalClouds.material_id = 4;
  return finalClouds;
}

SdfInformation lighthouseSdf(vec3 queryPos) {
  vec3 mainBodyPos = queryPos - vec3(-35.0, 16.0, 100.0);
  SdfInformation mainBody = cappedConeSDF(mainBodyPos, 8.0, 4.0, 2.8);
  mainBody.material_id = 5;

  vec3 balconyPos = queryPos - vec3(-35.0, 23.0, 100.0);
  SdfInformation balcony = torusSDF(balconyPos, vec2(3.0, 1.0));
  balcony.material_id = 6;

  SdfInformation window = capsuleSDF(queryPos, vec3(-35.0, 22.0, 100.0), vec3(-35.0, 26.0, 100.0), 2.5);
  window.material_id = 7;

  vec3 capPos = queryPos - vec3(-35.0, 29.0, 100.0);
  SdfInformation cap = cappedConeSDF(capPos, 2.0, 4.0, 0.5);
  cap.material_id = 8;

  vec3 ballPos = queryPos - vec3(-35.0, 31.0, 100.0);
  SdfInformation ball = torusSDF(ballPos, vec2(0.2, 0.6));
  ball.material_id = 9;

  SdfInformation lighthouse = smoothUnion(mainBody, balcony, 0.0);
  lighthouse = smoothUnion(lighthouse, window, 0.0);
  lighthouse = smoothUnion(lighthouse, cap, 0.0);
  lighthouse = smoothUnion(lighthouse, ball, 0.0);

  return lighthouse;
}

SdfInformation sceneSDF(vec3 queryPos) 
{
  SdfInformation land = landSdf(queryPos);
  float waterHeight = sin(u_Time / 1000.0) - 1.0; // overall tide goes in and out
  float smallWaveOffset = sin(u_Time / 20.0) - 1.0;
  waterHeight += 0.3 * smallWaveOffset;
  waterHeight += 0.1 * sin(u_Time / 10.0); // gives small wave motion
  SdfInformation water = ghibliWaterSDF(queryPos, waterHeight);

  SdfInformation wave = waveSDF(queryPos, 41.0);

  float cloudOffset = mod((u_Time / 10.0 + 350.0), 600.0) - 350.0;
  float smoothAmt = 0.5;
  SdfInformation cloud1 = cloudSdf(queryPos, vec3(-80.0 + cloudOffset, 40.0, 150.0), 1.2);
  SdfInformation cloud2 = cloudSdf(queryPos, vec3(-50.0 + cloudOffset, 50.0, 250.0), 1.0);
  SdfInformation cloud3 = cloudSdf(queryPos, vec3(0.0 + cloudOffset, 50.0, 180.0), 1.0);
  SdfInformation cloud4 = cloudSdf(queryPos, vec3(50.0 + cloudOffset, 40.0, 150.0), 1.0);
  SdfInformation cloud5 = cloudSdf(queryPos, vec3(140.0 + cloudOffset, 60.0, 250.0), 1.0);

  SdfInformation clouds = smoothUnion(cloud1, cloud2, smoothAmt);
  clouds = smoothUnion(clouds, cloud3, smoothAmt);
  clouds = smoothUnion(clouds, cloud4, 0.0);
  clouds = smoothUnion(clouds, cloud5, 0.0);

  SdfInformation lighthouse = lighthouseSdf(queryPos);

  SdfInformation scene = smoothUnion(land, lighthouse, smoothAmt);
  scene = smoothUnion(scene, clouds, smoothAmt);
  scene = smoothUnion(scene, wave, smoothAmt);
  scene = smoothUnion(scene, water, smoothAmt);

  return scene;
}

// converts uv coordinate to ray
Ray getRay(vec2 uv) {
    Ray ray;

    float camSpeed = 0.0;

    vec3 movingEye = EYE + vec3(0.0, 0.0, -u_Time * camSpeed);
    vec3 movingRef = REF + vec3(0.0, 0.0, -u_Time * camSpeed);

    float len = tan(3.14159 * 0.125) * distance(movingEye, movingRef);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), movingRef - movingEye));
    vec3 V = normalize(cross(H, movingEye - movingRef));
    V *= len;
    H *= len * u_Dimensions.x / u_Dimensions.y;
    vec3 p = movingRef + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - movingEye);
    
    ray.origin = movingEye;
    ray.direction = dir;
    return ray;
}

// raymarches for uv coordinate and returns intersection
Intersection getRaymarchedIntersection(vec2 uv)
{
    Ray ray = getRay(uv);
    Intersection intersection;
    
    vec3 queryPoint = ray.origin;
    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        SdfInformation sdfInformation = sceneSDF(queryPoint);
        float distanceToSurface = sdfInformation.distance;
        
        if (distanceToSurface < EPSILON)
        {
            
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);
            intersection.material_id = sdfInformation.material_id;
            
            return intersection;
        }
        
        // move along ray drxn by amt returned from sdf (sphere tracing)
        float incrAmt = max(distanceToSurface, 0.0);
        queryPoint = queryPoint + ray.direction * incrAmt;

        // break if max distance reached
        if(length(queryPoint - ray.origin) > 300.0) {
          break;
        }
    }
    
    intersection.distance = -1.0;
    return intersection;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).distance - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).distance,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).distance - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).distance,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).distance - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).distance
    ));
}

vec3 mixDayNightColor(vec3 dayColor, vec3 nightColor, float time) {
  // time is given is -1 to 1 range, remap to 0.0 to 1.0 for mix
  time = remap(time, -1.0, 1.0, 0.0, 1.0);
  return mix(dayColor, nightColor, time);
}

vec3 getBackgroundColor(vec2 uv, float time) {
  // sky background
  vec3 topColor = mixDayNightColor(vec3(0.1, 0.7, 0.9), vec3(0.02, 0.05, 0.15), time);
  vec3 bottomColor = mixDayNightColor(vec3(0.8, 0.95, 1.0), vec3(0.05, 0.2, 0.6), time);
  float mixAmount = clamp(uv.y+ fbm(0.0, uv.x, uv.y, 10.0, 0.2, 4, 0.4), 0.0, 1.0);
  mixAmount = getBias(mixAmount, 0.7);
  float numSkyColors = 10.0;
  mixAmount = floor(mixAmount * numSkyColors) / numSkyColors;
  vec3 color = mix(bottomColor, topColor, mixAmount);

  // help cover artifacts in ocean
  if(uv.y < 0.0) {
    color = mixDayNightColor(vec3(0.14, 0.4, 0.85), vec3(0.03, 0.15, 0.45), time);
  }
  return color;
}
vec3 cloudMaterial(vec3 normal, vec3 lightDir, float time) {
  vec3 returnColor = vec3(0.0);

  float facingLight = max(0.0, dot(normal, lightDir));
  float facingCam = max(0.0, dot(normal, vec3(0.0, 0.0, -1.0)));

  // main toon shading effect
  if(facingLight < 0.05) {
    returnColor += mixDayNightColor(vec3(0.4, 0.6, 0.8), vec3(0.2, 0.4, 0.7), time);
  } else if(facingLight < 0.5) {
    returnColor += mixDayNightColor(vec3(0.5, 0.7, 0.9), vec3(0.3, 0.5, 0.8), time);
  } else {
    returnColor += mixDayNightColor(vec3(0.6, 0.8, 1.0), vec3(0.4, 0.6, 0.9), time);
  }

  // slight outline overlay
  if(facingCam < 0.8) {
    returnColor += 0.025 * mixDayNightColor(vec3(0.7, 0.9, 1.0), vec3(0.5, 0.7, 0.9), time);
  }

  return returnColor;
}
vec3 hillMaterial(vec3 normal, vec3 lightDir, vec3 pos, float time) {
  vec3 returnColor = vec3(0.0);

  float facingLight = max(0.0, dot(normal, lightDir));
  float facingCam = max(0.0, dot(normal, vec3(0.0, 0.0, -1.0)));

  float noisyPosSand = pos.y + fbm(pos.x, pos.y, pos.z, 0.15, 2.5, 1, 0.5);

  float noisyPosDirt = pos.y + fbm(pos.x, pos.y, pos.z, 0.15, 2.5, 1, 0.5);
  noisyPosDirt += fbm(pos.x, pos.y, pos.z, 0.65, 5.0, 1, 0.5);

  if(noisyPosSand < 0.0){
    // sand
    if(facingCam < 0.6) {
      returnColor += mixDayNightColor(vec3(0.9, 0.7, 0.4),vec3(0.5, 0.3, 0.28), time);
    } else {
      returnColor += mixDayNightColor(vec3(0.8, 0.6, 0.3), vec3(0.43, 0.25, 0.2), time);
    } 
    if(facingLight > 0.6) {
      returnColor += 0.05 * mixDayNightColor(vec3(0.9, 0.8, 0.4), vec3(0.7, 0.6, 0.3), time);
    }
  } else if(noisyPosDirt < 8.0) {
    // dirt
    if(facingLight < 0.65) {
      returnColor += mixDayNightColor(vec3(0.38, 0.15, 0.05), vec3(0.2, 0.1, 0.1), time);
    } else {
      returnColor += mixDayNightColor(vec3(0.4, 0.2, 0.1), vec3(0.25, 0.13, 0.1), time);
    } 

    if(facingCam < 0.2 || facingLight > 0.8) {
      returnColor += 0.2 * mixDayNightColor(vec3(0.5, 0.3, 0.2), vec3(0.4, 0.2, 0.2), time);
    }
  } else {
    // grass
    returnColor += mixDayNightColor(vec3(0.3, 0.5, 0.2), vec3(0.05, 0.2, 0.15), time);

    if(facingCam < 0.2) {
      returnColor += 0.2 * mixDayNightColor(vec3(0.3, 0.4, 0.3), vec3(0.1, 0.2, 0.25), time);
    }
  }

  return returnColor;
}
vec3 waterMaterial(int material_id, vec3 pos, float time) {
  vec3 waterColor = vec3(0.0);

  if(material_id == 0) {
    // water dark
    waterColor += mixDayNightColor(vec3(0.14, 0.4, 0.85), vec3(0.03, 0.15, 0.45), time);
  } else if (material_id == 1) {
    // water light
    waterColor += mixDayNightColor(vec3(0.2, 0.6, 0.9), vec3(0.05, 0.25, 0.5), time);
  } else if (material_id == 2) {
    // water spec
    waterColor += mixDayNightColor(vec3(0.45, 0.85, 1.0), vec3(0.1, 0.4, 0.6), time);
  }

  SdfInformation landSdf = landLargeProxySdf(pos);

  float smallWaveOffset = (sin(u_Time / 20.0) + 1.0) / 2.0;

  vec3 foamColor = mixDayNightColor(vec3(0.8, 0.8, 0.9), vec3(0.6, 0.6, 0.7), time);
  if(landSdf.distance < -1.0) {
    waterColor += smallWaveOffset * 0.6 * foamColor;
  } else if (landSdf.distance < -0.5) {
    waterColor += smallWaveOffset * 0.4 * foamColor;
  } else if (landSdf.distance < 0.4 && (pos.z > 90.0 || pos.x < -30.0)) {
    waterColor += smallWaveOffset * 0.6 * foamColor;
  }

  return waterColor;
}
vec3 lighthouseMaterial(int material_id, vec3 pos, vec3 normal, vec3 lightDir, vec2 uv, float time) {
  vec3 returnColor = vec3(0.0);
  float facingLight = max(0.0, dot(normal, lightDir));

  vec3 red = vec3(0.0);
  vec3 white = vec3(0.0);
  vec3 blue = vec3(0.0);

  if (facingLight < 0.3) {
    red = mixDayNightColor(vec3(0.9, 0.05, 0.05), vec3(0.6, 0.05, 0.08), time);
    white = mixDayNightColor(vec3(0.8, 0.8, 0.9), vec3(0.55, 0.55, 0.7), time);
    blue = mixDayNightColor(vec3(0.01, 0.03, 0.07), vec3(0.01, 0.01, 0.03), time);
  }  else if (facingLight < 0.7) {
    red = mixDayNightColor(vec3(1.0, 0.1, 0.1), vec3(0.65, 0.1, 0.1), time);
    white = mixDayNightColor(vec3(0.9, 0.9, 0.95), vec3(0.6, 0.6, 0.75), time);
    blue = mixDayNightColor(vec3(0.04, 0.06, 0.1), vec3(0.02, 0.03, 0.05), time);
  } else {
    red = mixDayNightColor(vec3(1.0, 0.25, 0.2), vec3(0.7, 0.12, 0.15), time);
    white = mixDayNightColor(vec3(1.0, 0.95, 0.95), vec3(0.8, 0.75, 0.75), time);
    blue = mixDayNightColor(vec3(0.1, 0.14, 0.25), vec3(0.05, 0.05, 0.1), time);
  }

  if(material_id == 5){
    // 5 = mainbody
    float stripe = sin(pos.y * 1.1 + 3.0);
    if(stripe > 0.0) {
      returnColor = red;
    } else {
      returnColor = white;
    }
  } else if (material_id == 6) {
    // 6 = balcony
    returnColor = blue;
  } else if (material_id == 7) {
    // 7 = window
    if(pos.y < 24.5 || pos.y > 26.5 || pos.x < -36.0 || pos.x > -32.7 || ( pos.x < -33.5 && pos.x > -34.5)) {
      returnColor = white;
    } else {
      returnColor = getBackgroundColor(uv, time);
    }
  } else if (material_id == 8) {
    // 8 == top cone
    returnColor = red;
  } else if (material_id == 9) {
    // 9 == top ball
    returnColor = white;
  }

  return returnColor;
}
vec3 getMaterialColor(int material_id, vec3 normal, vec3 lightDir, vec3 pos, vec2 uv, float time) {
  if(material_id <= 2 && material_id >= 0) {
    return waterMaterial(material_id, pos, time);
  } else if (material_id == 3) {
    // ground
    return hillMaterial(normal, lightDir, pos, time);
  } else if (material_id == 4) {
    // cloud
    return cloudMaterial(normal, lightDir, time);
  } else if(material_id >= 5 && material_id <= 9) {
    // lighthouse
    return lighthouseMaterial(material_id, pos, normal, lightDir, uv, time);
  } else {
    return vec3(1.0, 0.0, 1.0);
  }
}
vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    // sunTime > 0.0 = night, sunTime < 0.0 = day
    float sunTime = -cos(u_Time / 100.0);
    float lightDrxnX = remap(sunTime, -1.0, 1.0, -10.0, 10.0);
    float lightDrxnZ = remap(sunTime, -1.0, 1.0, -10.0, 10.0);

    DirectionalLight light = DirectionalLight(normalize(vec3(lightDrxnX, 12.0, lightDrxnZ)),
                                 SUN_KEY_LIGHT);
    
    vec3 color = vec3(0.0);

    if (intersection.distance > 0.0)
    { 
        // shading
        vec3 n = estimateNormal(intersection.position);
        color = getMaterialColor(intersection.material_id, n, light.dir, intersection.position, uv, sunTime);
        
        // clouds are transparent
        if(intersection.material_id == 4) {
          color *= 0.8;
          color += 0.4 * getBackgroundColor(uv, sunTime);
        }
    }
    else
    {
        // sky background
        color = getBackgroundColor(uv, sunTime);
    }
    // gamma correction
    color = pow(color, vec3(1. / 2.2));
    return color;
}

void main() {
  // define scene ()
  // call raymarch function

  // Normalized pixel coordinates (from 0 to 1)
  vec2 uv = fs_Pos;

  // Time varying pixel color
  vec3 col = getSceneColor(uv);

  // Output to screen
  out_Col = vec4(col,1.0);
}