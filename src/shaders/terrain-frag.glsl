#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

#define MAX_STEPS 100
#define MAX_DIST 100.f
#define SURF_DIST 0.01
#define PI 3.14
#define SHOWMOUNTAINS 0

// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define MOON_KEY_LIGHT vec3(1.0, 1.0, 1.0) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.2, 0.502, 0.702) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define MOON_AMBIENT_LIGHT vec3(1.0, 1.0, 1.0) * 0.2
const float EPSILON = 1e-2;

#define WATER 0
#define STAFF 1
#define SAIL 2
#define YACHT 3
#define TERRAIN 4

const vec4 material_colors[5] = vec4[](
    vec4(0.1333, 0.2, 0.3882, 0.856),
    vec4(0.1412, 0.1412, 0.1451, 1.0),
    vec4(0.9216, 0.0902, 0.0902, 1.0),
    vec4(0.1451, 0.0706, 0.0314, 1.0),
    vec4(0.0667, 0.1059, 0.0588, 1.0)
);

struct Ray 
{
    vec3 origin;
    vec3 direction;
};

struct Material
{
    int type;
    vec3 color;
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

struct Geom {
    float t;
    int material_id;    
};
/*
 ******************************************************
 * Noise Functions
 ******************************************************
 */

// 2D noise functions
float hash2D( vec2 p ) { float h = dot(p,vec2(127.1,311.7)); return fract(sin(h)*43758.5453123); }

float noise( in vec2 p ) {
    vec2 i = floor( p );
    vec2 f = fract( p );	
	vec2 u = f*f*(3.0-2.0*f);
    return -1.0+2.0*mix( mix( hash2D( i + vec2(0.0,0.0) ), 
                     hash2D( i + vec2(1.0,0.0) ), u.x),
                mix( hash2D( i + vec2(0.0,1.0) ), 
                     hash2D( i + vec2(1.0,1.0) ), u.x), u.y);
}


float hash( float n )
{
    return fract(sin(n)*43758.5453);
}

float map(float value, float min, float max){
	return clamp((value - min)/(max - min), 0.f, 1.f);
}

// 3D noise functions
float random3D( vec3 x )
{
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f*f*(3.0-2.0*f);

    float n = p.x + p.y*57.0 + p.z * 50.0;

    return mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
               mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
}

float interpNoise3D(vec3 p) {
    int intX = int(floor(p.x));
    float fractX = fract(p.x);
    int intY = int(floor(p.y));
    float fractY = fract(p.y);
    int intZ = int(floor(p.z));
    float fractZ = fract(p.z);

    float v1 = random3D(vec3(intX, intY, intZ));
    float v2 = random3D(vec3(intX, intY, intZ + 1));
    float v3 = random3D(vec3(intX, intY + 1, intZ));
    float v4 = random3D(vec3(intX, intY + 1, intZ + 1));

    float v5 = random3D(vec3(intX + 1, intY, intZ));
    float v6 = random3D(vec3(intX + 1, intY, intZ + 1));
    float v7 = random3D(vec3(intX + 1, intY + 1, intZ));
    float v8 = random3D(vec3(intX + 1, intY + 1, intZ + 1));

    float i1 = mix(v1, v2, fractZ);
    float i2 = mix(v3, v4, fractZ);
    float i3 = mix(i1, i2, fractY);
    
    float i4 = mix(v5, v6, fractZ);
    float i5 = mix(v7, v8, fractZ);
    float i6 = mix(i4, i5, fractY);

    return mix(i3, i6, fractX);
}

float random2D( vec2 p )
{
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float interpNoise2Dcosine(vec2 p) {
    int intX = int(floor(p.x));
    float fractX = fract(p.x);
    int intY = int(floor(p.y));
    float fractY = fract(p.y);

    float v1 = random2D(vec2(intX, intY));
    float v2 = random2D(vec2(intX + 1, intY));
    float v3 = random2D(vec2(intX, intY + 1));
    float v4 = random2D(vec2(intX + 1, intY + 1));

    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);
    return cosineInterpolate(i1, i2, fractY);
}

float fbm2Dcosine(vec2 p, float freq, float persistence, float amp) {
    float total = 0.f;
    int octaves = 8;
    for(int i = 1; i <= octaves; i++) {
        total += interpNoise2Dcosine(p.xy * freq) * amp;
        freq *= 2.f;
        amp *= pow(persistence, float(i));
    }
    return total;
}

float interpNoise2D(vec2 p) {
    int intX = int(floor(p.x));
    float fractX = fract(p.x);
    int intY = int(floor(p.y));
    float fractY = fract(p.y);

    float v1 = random2D(vec2(intX, intY));
    float v2 = random2D(vec2(intX + 1, intY));
    float v3 = random2D(vec2(intX, intY + 1));
    float v4 = random2D(vec2(intX + 1, intY + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}

float fbm2D(vec2 p, float freq, float persistence, float amp) {
    float total = 0.f;
    int octaves = 8;
    for(int i = 1; i <= octaves; i++) {
        total += interpNoise2D(p.xy * freq) * amp;
        freq *= 2.f;
        amp *= persistence;//pow(persistence, float(i));
    }
    return total;
    
    // for(int i = 1; i <= octaves; i++) {
    //     amp = pow(persistence, float(i));
    //     total += interpNoise2D(p.xy * freq) * amp;
    // }
    // return total;
}
/*
 ******************************************************
 * Signed Distance Functions - Primitives
 ******************************************************
 */
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

float roundedCylinderSDF( vec3 queryPos, float ra, float rb, float h )
{
  vec2 d = vec2( length(queryPos.xz)-2.0*ra+rb, abs(queryPos.y) - h );
  return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rb;
}

float ellipsoidSDF( vec3 p, vec3 r )
{
  float k0 = length(p/r);
  float k1 = length(p/(r*r));
  return k0*(k0-1.0)/k1;
}

float triPrismSDF( vec3 p, vec2 h )
{
  vec3 q = abs(p);
  return max(q.z-h.y,max(q.x*0.866025+p.y*0.5,-p.y)-h.x*0.5);
}

float triangleSDF( vec2 p, vec2 p0, vec2 p1, vec2 p2 )
{
    vec2 e0 = p1-p0, e1 = p2-p1, e2 = p0-p2;
    vec2 v0 = p -p0, v1 = p -p1, v2 = p -p2;
    vec2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot(e0,e0), 0.0, 1.0 );
    vec2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot(e1,e1), 0.0, 1.0 );
    vec2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot(e2,e2), 0.0, 1.0 );
    float s = sign( e0.x*e2.y - e0.y*e2.x );
    vec2 d = min(min(vec2(dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
                     vec2(dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))),
                     vec2(dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x)));
    return -sqrt(d.x)*sign(d.y);
}
/*
 ******************************************************
 * Signed Distance Functions - Operations
 ******************************************************
 */
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

vec3 rotateY(vec3 p, float amt) {
    return vec3(cos(amt) * p.x + sin(amt) * p.z, p.y, -sin(amt) * p.x + cos(amt) * p.z);
}

vec3 rotateX(vec3 p, float amt) {
    return vec3(p.x, cos(amt) * p.y - sin(amt) * p.z, sin(p.y) + cos(p.z));
}

mat2 rot(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float opExtrusion(vec3 p, float h, float d )
{
    vec2 w = vec2( d, abs(p.z) - h );
    return min(max(w.x,w.y),0.0) + length(max(w,0.0));
}

/*
 ******************************************************
 * Signed Distance Functions - Scene
 ******************************************************
 */

Geom yachtSDF(vec3 p, float angle) {
    vec3 pRot = p;
    pRot.xz = pRot.xz * rot(PI * 0.5);
    pRot.yz = pRot.yz * rot(PI);
    pRot.yz = pRot.yz * rot(angle);

    float dOuter = triPrismSDF(pRot, vec2(1.5f, 5.f));//ellipsoidSDF(p, vec3(7.5f, 2.5f, 2.5f));
    float dInner = triPrismSDF(pRot + vec3(0.f, 0.5f, 0.f), vec2(1.3f, 4.7f));//ellipsoidSDF(p - vec3(0.f, 1.f, 0.f), vec3(6.5f, 2.2f, 2.f));
    
    Geom gYacht;
    gYacht.t = max(dOuter, -dInner);
    gYacht.material_id = 3;
    return gYacht;
}


Geom staffSDF(vec3 p, float angle) {
    p.xy = p.xy * rot(-angle);
    float dStaff = capsuleSDF(p, vec3(0.0, 0.0, 0.0), vec3(0.0, 5.f, 0.0), 0.1f);

    Geom gStaff;
    gStaff.t = dStaff;
    gStaff.material_id = 1;
    return gStaff;
}

Geom sailSDF(vec3 p, float angle) {
    
    p.xy = p.xy * rot(-angle);
    float dSailTri = triangleSDF(p.xy, vec2(0.0, 0.75f), vec2(0.0, 5.f), vec2(2.f, 0.75f));
    float dSail = opExtrusion(p, 0.01f, dSailTri);

    Geom gSail;
    gSail.t = dSail;
    gSail.material_id = 2;
    return gSail;
}

Geom oceanSDF(vec3 p) {
    float waveNoise = (sin(p.x * 0.1 *  sin(u_Time)) * 0.5f + 1.f);
    float fbmWave = fbm2Dcosine(p.xz * 0.1f, 0.5, 0.2, 5.f );
    float yOffset = -5.f; 
    float waveHeight = fbmWave + yOffset;
    Geom gOcean;
    gOcean.t = planeSDF(vec3(p.x , p.y, p.z),  waveNoise + waveHeight);
    gOcean.material_id = 0;
    return gOcean;
}

Geom mountainsSDF(vec3 p) {
    // textured plane
    
    float dMountain = 0.f;
    dMountain = planeSDF(p, fbm2D((p.xz * 0.20f), 0.1f, 0.1, 50.f));
    float dTerrain = planeSDF(p + vec3(0.0, 1.75f, 0.0), fbm2D((p.xz), 0.8, 0.1, 1.f));
    Geom gMountain;
    gMountain.t = dMountain;// + dTerrain;
    gMountain.material_id = 4;
    return gMountain;
}

Geom sceneSDF(vec3 p) {

    p += vec3(0.f, 3.f, 0.f);

    // Ocean
    Geom gTerrain;

#if SHOWMOUNTAINS
    float fbmVal = map(fbm2Dcosine(p.xz * 0.1f, 0.5f, 0.01f, 1.f), 0.f, 1.f);
    if(fbmVal > 0.75f) {
        gTerrain = mountainsSDF(p);
    }
    else{
        gTerrain = oceanSDF(p);
    }
#else
    gTerrain = oceanSDF(p);
#endif
    // Yacht
    vec3 pYacht = p + vec3(0.f, 0.f, -5.f);
    float angle = 0.05 * sin(PI * u_Time * 0.2);
    Geom gYacht = yachtSDF(pYacht, angle);
    Geom gStaff = staffSDF(pYacht, angle);
    Geom gFlag = sailSDF(pYacht, angle);

    Geom allGeoms[4] = Geom[4](gTerrain, gYacht, gStaff, gFlag);
    float min = MAX_DIST;
    int geomIdx = 0;
    for(int i = 0; i < 4; i++) {
        if(min > allGeoms[i].t) {
            min = allGeoms[i].t;
            geomIdx = i;
        }
    }
    return allGeoms[geomIdx];
}

/*
 ******************************************************
 * Ray Marching
 ******************************************************
 */

Ray getRay(vec2 uv) {
    Ray ray;

    vec3 ref = normalize(u_Ref);
    vec3 R = normalize(cross(u_Up, u_Ref - u_Eye));
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);  //length(u_Ref - u_Eye);
    vec3 V = len * u_Up;    // * u_Dimensions.y/2.f;
    vec3 H = len * R * u_Dimensions.x/u_Dimensions.y;   // u_Dimensions.x/2.f;

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
    for (int i=0; i < MAX_STEPS; ++i)
    {
        Geom geometry = sceneSDF(queryPoint);
        float distanceToSurface = geometry.t;
        
        if (distanceToSurface < EPSILON)
        {
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            vec3(0.4471, 0.4471, 0.8863);
            intersection.distance = length(queryPoint - ray.origin);
            intersection.material_id = geometry.material_id;
            return intersection;
        }
        
        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }
    
    intersection.distance = -1.0;
    return intersection;
}

/*
 ******************************************************
 * Light Estimation
 ******************************************************
 */

vec3 scatter(vec3 rayOrigin, vec3 rayDirection, vec3 lightDirection)
{   
    float sd= max(dot(lightDirection, rayDirection) * 0.5 + 0.5, 0.f);
    float dtp = 13.f-(rayOrigin + rayDirection * float(MAX_STEPS)).y * 9.5;
    float hori = (map(dtp, -1500.f, 0.0) - map(dtp, 11.f, 500.f)) * 1.f;
    hori *= pow(sd, 0.02);
    
    vec3 col = vec3(0);
    col += pow(hori, 200.f) * vec3(0.2118, 0.2, 0.3882) * 3.f;
    col += pow(hori, 25.f) * vec3(0.1804, 0.2078, 0.6314) * 0.3;
    col += pow(hori, 7.f) * vec3(0.1098, 0.0745, 0.2941) * 0.8;
    
    return col;
}

vec3 stars(vec3 rayDir) {
    float star = random2D(vec2(rayDir.x, rayDir.y)) * 1.001;
    vec3 starRadDir;
    float newangle = 0.0;

    if(floor(star) != 0.0) {      //there is a star here
        return vec3(1, 1, 1);
    }

    return vec3(0.0);
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).t - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).t,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).t - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).t,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).t - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).t
    ));
}

vec4 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    Ray ray = getRay(uv);
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 MOON_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 MOON_AMBIENT_LIGHT);
    
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 MOON_KEY_LIGHT);
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 MOON_AMBIENT_LIGHT);
    backgroundColor = MOON_KEY_LIGHT;

    vec4 terrainColor = vec4(0.5, 0.9, 0.7, 1.0);

    vec4 albedo = material_colors[intersection.material_id];
    vec3 n = estimateNormal(intersection.position);
        
    vec3 color = albedo.xyz *
                 lights[0].color *
                 max(0.0, dot(n, lights[0].dir));
    
    if (intersection.distance > 0.0)
    { 
        for(int i = 1; i < 3; ++i) {
            color += albedo.xyz *
                     lights[i].color *
                     max(0.0, dot(n, lights[i].dir));
        }
    }
    else
    {
        vec3 horizon = scatter(ray.origin, ray.direction, lights[0].dir);
        vec3 star = stars(vec3(sin(u_Time * 0.00005) * 0.00001, ray.direction.y, ray.direction.z));

        color = vec3(0.0);
        color = star * (1.0 - clamp(dot(horizon, vec3(0.8)), 0.0, 1.0));
        color += horizon * 0.7;
    }

    color = pow(color, vec3(1. / 2.2));
    return vec4(color.xyz, albedo.w);
}

void main() {
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy/u_Dimensions.xy;
    
    // Make symmetric [-1, 1]
    uv = uv * 2.0 - 1.0;

    // Time varying pixel color
    vec4 col = getSceneColor(uv);

    // Output to screen
    out_Col = vec4(col);
    // out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}
