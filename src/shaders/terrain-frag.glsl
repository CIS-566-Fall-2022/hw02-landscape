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

// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define SUN_KEY_LIGHT vec3(0.6, 1.0, 0.4) * 1.5
// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.7, 0.2, 0.7) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.6, 1.0, 0.4) * 0.2
const float EPSILON = 1e-2;

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

/*
 ******************************************************
 * Noise Functions
 ******************************************************
 */

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

float random2D( vec2 x )
{
    vec2 p = floor(x);
    vec2 f = fract(x);

    f = f*f*(3.0-2.0*f);

    float n = p.x*57.0 + p.y * 50.0;

    return mix(mix( hash(n+  0.0), hash(n+  1.0),f.x),
               mix( hash(n+ 57.0), hash(n+ 58.0),f.x),f.y);
}

float interpNoise2D(vec2 p) {
    int intX = int(floor(p.x));
    float fractX = fract(p.x);
    int intY = int(floor(p.y));
    float fractY = fract(p.y);

    float v1 = hash2D(vec2(intX, intY));
    float v2 = hash2D(vec2(intX + 1, intY));
    float v3 = hash2D(vec2(intX, intY + 1));
    float v4 = hash2D(vec2(intX + 1, intY + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}

float surflet(vec2 P, vec2 gridPoint) {
    // Compute falloff function by converting linear distance to a polynomial
    float distX = abs(P.x - gridPoint.x);
    float distY = abs(P.y - gridPoint.y);
    float tX = 1.f - 6.f * pow(distX, 5.f) + 15.f * pow(distX, 4.f) - 10.f * pow(distX, 3.f);
    float tY = 1.f - 6.f * pow(distY, 5.f) + 15.f * pow(distY, 4.f) - 10.f * pow(distY, 3.f);
    // Get the random vector for the grid point
    vec2 gradient = 2.f * random3D(vec3(gridPoint.xy, 1.0)) - vec2(1.f);
    // Get the vector from the grid point to P
    vec2 diff = P - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * tX * tY;
}

float perlinNoise(vec2 uv) {
	float surfletSum = 0.f;
	// Iterate over the four integer corners surrounding uv
	for(int dx = 0; dx <= 1; ++dx) {
		for(int dy = 0; dy <= 1; ++dy) {
			surfletSum += surflet(uv, floor(uv) + vec2(dx, dy));
		}
	}
	return surfletSum;
}

float fbm2D(vec2 p, float freq, float persistence, float amp) {
    // float total = 0.f;
    // //float persistence = 0.5f;
    // int octaves = 8;
    // //float freq = 2.f;
    // //float amp = 2.f;//0.5f;
    // for(int i = 1; i <= octaves; i++) {
    //     total += interpNoise2D(p.xy * freq) * amp;
    //     freq *= 2.f;
    //     amp *= persistence;
    // }
    // return total;
	float v = 0.0;
    int octaves = 8;
	vec2 shift = vec2(100);
	// Rotate to reduce axial bias
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
	for (int i = 0; i < octaves; ++i) {
		v += amp * interpNoise2D(p);
		p = rot * p * 2.0 + shift;
		amp *= persistence;
	}
	return v;
}

float mountainHeightFunc(vec3 p) {
    //vec2 randomOffset = vec2(hash(p.x/12.f), hash(p.z/12.f)) * 0.2f;
    // vec2 randomOffset = vec2(0.3f, 0.3f);
    float fbmMountains = fbm2D((p.xz) / 12.f, 0.5, 0.2, 18.f); //fbm2D((p.xz) * 0.007f, 0.6, 0.2, 400.f);
    float terrainNoise = -1.f * fbm2D(p.xz, 0.5, 0.5, 0.8f);
    float yOffset = -2.f;
    return  fbmMountains + terrainNoise + yOffset;
}   

/*
 ******************************************************
 * Signed Distance Functions
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

float sceneSDF(vec3 p, inout float mtHeight) {

    //float dS = sphereSDF(p, vec3(0,1,0), 1.f);
    mtHeight = mountainHeightFunc(p);
    //float dMountain = planeSDF(p, mtHeight);

    float dMugOuter = roundedCylinderSDF( p, 0.6f, 0.2f, 1.f);
    float dMugInner = roundedCylinderSDF( p - vec3(0.f, 0.4f, 0.f), 0.5f, 0.2f, 1.f);
    float dMug = max(dMugOuter, -dMugInner);

    //float d = min(dMug, dMountain);
    float d = dMug;
    return d;
    
    // vec3 capsuleA = vec3(-1.f, 1.f, 2.f);
    // vec3 capsuleB = vec3(1.f, 1.f, 1.f);
    // float dRiverBed = capsuleSDF(p, capsuleA, capsuleB, 10.f);
    //float dRiver = max(dMountain, -dRiverBed);
    //float dWater = planeSDF(p, 2.f);
    // dRiver = max(dWater, dRiver);
    // float d = dRiver;

    // vec4 sphere = vec4(0,1,0,1);    // center.xyz,radius
    // float dS = length(p - sphere.xyz) - sphere.w; // dist from sphere = dist from center - radius
    // float dP = p.y; // dist from axis aligned plane
    // float d = min(dS,dP);
    // // float d = dS;
    // return d;
}

/*
 ******************************************************
 * Ray Marching
 ******************************************************
 */

 
// vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
//     vec2 xy = fragCoord - size / 2.0;
//     float z = size.y / tan(radians(fieldOfView) / 2.0);
//     return normalize(vec3(xy, -z));
// }

Ray getRay(vec2 uv) {
    Ray ray;

    vec3 ref = normalize(u_Ref);
    vec3 R = normalize(cross(u_Up, u_Ref - u_Eye));
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);  //length(u_Ref - u_Eye);
    vec3 V = len * u_Up;    // * u_Dimensions.y/2.f;
    vec3 H = len * R * u_Dimensions.x/u_Dimensions.y;   // u_Dimensions.x/2.f;

    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);

    // vec3 dir = rayDirection(45.0f, u_Dimensions.xy, gl_FragCoord.xy);
    // vec3 eye = vec3(0.0, 0.0, 5.0);

    ray.origin = u_Eye;
    ray.direction = dir;
    return ray;
}


Intersection getRaymarchedIntersection(vec2 uv, out float mtHeight)
{
    Ray ray = getRay(uv);
    Intersection intersection;
    
    // if(ray.origin.x > 10.f || ray.origin.x < -10.f ||
    //     ray.origin.z > 10.f || ray.origin.z < -10.f ){
    //         intersection.position = ray.origin;
    //         intersection.distance = 0.f;
    //         intersection.normal = vec3(0.0, 0.0, 1.0);
    //         return intersection;
    // }

    vec3 queryPoint = ray.origin;
    for (int i=0; i < MAX_STEPS; ++i)
    {
        float distanceToSurface = sceneSDF(queryPoint, mtHeight);
        
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
    
    //     float dO = 0.f;
    //     float dS;
    //     for(int i = 0; i < MAX_STEPS; i++) {
    //         vec3 p = ro + dO * rd;
    //         dS = GetDist(p);
    //         dO += dS;
    //         if(dS < SURF_DIST || dO > MAX_DIST) {    // max steps reached/max dist reached/ surface has been hit
    //             break;
    //         }
    //     }
    //     return dO;
}

/*
 ******************************************************
 * Light Estimation
 ******************************************************
 */
vec3 estimateNormal(vec3 p) {
    float mtHeightTemp;
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z), mtHeightTemp) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z), mtHeightTemp),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z), mtHeightTemp) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z), mtHeightTemp),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON), mtHeightTemp) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON), mtHeightTemp)
    ));
}

vec3 getSceneColor(vec2 uv)
{
    float mtHeight;
    Intersection intersection = getRaymarchedIntersection(uv, mtHeight);
    
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
    
    vec3 waterColor = vec3(0.0, 0.0, 1.0);
    vec3 iceColor = vec3(1.0, 1.0, 1.0);
    vec3 terrainColor = vec3(0.5, 0.9, 0.7);

    vec3 albedo = terrainColor;
    // if(mtHeight > 12.f) {
    //     albedo = iceColor;
    // }
    // else if(mtHeight < 2.f) {
    //     albedo = waterColor;
    // }

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
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = gl_FragCoord.xy/u_Dimensions.xy;
    
    // Make symmetric [-1, 1]
    uv = uv * 2.0 - 1.0;

    // Time varying pixel color
    vec3 col = getSceneColor(uv);

    // Output to screen
    out_Col = vec4(col,1.0);
    // out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
}
