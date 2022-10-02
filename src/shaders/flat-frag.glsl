#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

const int MAX_RAY_STEPS = 128;
const float FOV = 45.0;
const float EPSILON = 0.001f;
const float EULER_NUMBER = 2.71828f;
/* ---------------- Noise Functions ----------------*/

int[] perm = int[](
    151,160,137,91,90,15,
    131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
    190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
    88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
    77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
    102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
    135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
    5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
    223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
    129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
    251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
    49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
    138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
    151
);
int perm1plus(int i, int k) { return int(mod(float(perm[i]) + float(k), 256.)); }

float Fade(float t) { return t * t * t * (t * (t * 6. - 15.) + 10.); }

float Grad(int hash, float x, float y, float z) {
    int h = hash & 15;
    float u = h < 8 ? x : y;
    float v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
    return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
}

float Noise3D(vec3 val) {
    vec3 v1 = floor(val);
    vec3 v2 = fract(val);
    int X = int(mod(v1.x, 256.));
    int Y = int(mod(v1.y, 256.));
    int Z = int(mod(v1.z, 256.));
    float x = v2.x;
    float y = v2.y;
    float z = v2.z;
    float u = Fade(x);
    float v = Fade(y);
    float w = Fade(z);
    int A  = perm1plus(X, Y);
    int B  = perm1plus(X+1, Y);
    int AA = perm1plus(A, Z);
    int BA = perm1plus(B, Z);
    int AB = perm1plus(A+1, Z);
    int BB = perm1plus(B+1, Z);

    return mix(mix(mix(Grad(perm[AA  ], x, y   , z  ),  Grad(perm[BA  ], x-1., y   , z  ), u),
                   mix(Grad(perm[AB  ], x, y-1., z  ),  Grad(perm[BB  ], x-1., y-1., z  ), u),
                   v),
               mix(mix(Grad(perm[AA+1], x, y   , z-1.), Grad(perm[BA+1], x-1., y   , z-1.), u),
                   mix(Grad(perm[AB+1], x, y-1., z-1.), Grad(perm[BB+1], x-1., y-1., z-1.), u),
                   v),
               w);
}

// number of octaves of fbm
#define NUM_NOISE_OCTAVES 10

float hash(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }

float noise(vec3 x) {
    const vec3 step = vec3(110, 241, 171);
    vec3 i = floor(x);
    vec3 f = fract(x);
    float n = dot(i, step);
    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix( hash(n + dot(step, vec3(0, 0, 0))), hash(n + dot(step, vec3(1, 0, 0))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 0))), hash(n + dot(step, vec3(1, 1, 0))), u.x), u.y),
               mix(mix( hash(n + dot(step, vec3(0, 0, 1))), hash(n + dot(step, vec3(1, 0, 1))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 1))), hash(n + dot(step, vec3(1, 1, 1))), u.x), u.y), u.z);
}

float fbm(vec3 x) {
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100);
	for (int i = 0; i < NUM_NOISE_OCTAVES; ++i) {
		//v += a * noise(x);
        v += a * (Noise3D(x) * .5 + .5);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

/* ---------------- Struct ----------------*/
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

struct SDF{
    float sdf;
    int type;
};
/* ---------------- CSG Helper ----------------*/

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

/* ---------------- Helpers ----------------*/
// Range (-1,1)
float sin10x(float x){
    float res = sin(x);
    return res;
}

//2D signed hash function:
vec2 Hash2(vec2 P)
{
	return 1.-2.*fract(cos(P.x*vec2(91.52,-74.27)+P.y*vec2(-39.07,09.78))*939.24);
}

//2D Worley noise.
float worley(vec2 P)
{
    float D = 1.;
	vec2 F = floor(P+.5);
   	
    //Find the the nearest point the neigboring cells.
    D = min(length(.5*Hash2(F+vec2( 1, 1))+F-P+vec2( 1, 1)),D);
    D = min(length(.5*Hash2(F+vec2( 0, 1))+F-P+vec2( 0, 1)),D);
    D = min(length(.5*Hash2(F+vec2(-1, 1))+F-P+vec2(-1, 1)),D);
    D = min(length(.5*Hash2(F+vec2( 1, 0))+F-P+vec2( 1, 0)),D);
    D = min(length(.5*Hash2(F+vec2( 0, 0))+F-P+vec2( 0, 0)),D);
    D = min(length(.5*Hash2(F+vec2(-1, 0))+F-P+vec2(-1, 0)),D);
    D = min(length(.5*Hash2(F+vec2( 1,-1))+F-P+vec2( 1,-1)),D);
    D = min(length(.5*Hash2(F+vec2( 0,-1))+F-P+vec2( 0,-1)),D);
    D = min(length(.5*Hash2(F+vec2(-1,-1))+F-P+vec2(-1,-1)),D);
    return D;
}

/* ---------------- SDFs ----------------*/

float sphereSDF(vec3 query_position, vec3 position, float radius)
{
    return length(query_position - position) - radius;
}

float planeSDF(vec3 queryPos, float height)
{
    return queryPos.y - height;
}

SDF sceneSDF(vec3 queryPos) 
{
    // float mountainsNoise = fbm(queryPos.xyz * 1.5);
    float sphereNoise = noise(queryPos.xyz);
    
    float lowFreqDeform = 30.0f * (noise(0.05f * queryPos.xyz));  // Range(0, 20) 
    float hiFreqDeform = 10.0f * ((0.3f * noise(0.03f * queryPos.xyz) + 1.0) / 2.f);  // Range(0, 10) 
    // deform = smoothstep(0.0f, 10.0f, deform);
    float w = worley(0.01f*queryPos.xz) * 30.0f;

    float sphere = sphereSDF(queryPos, vec3(0.0f, 15.0f, -5.0f), sphereNoise + 1.0f);
    float plane = planeSDF(queryPos, w + hiFreqDeform + lowFreqDeform - 10.0f);
    // float plane = planeSDF(queryPos, w);

    float water = planeSDF(queryPos, 1.0f);
    SDF resSDF;
    if (plane < water) {
        float dist = smoothUnion(plane, sphere, 0.5);
        resSDF.sdf = dist;
        resSDF.type = 1;
        return resSDF;
    } else {
        float dist = smoothUnion(water, sphere, 0.5);
        resSDF.sdf = dist;
        resSDF.type = 2;
        return resSDF;
    }
    // return res;
}

/* ---------------- Ray Marching ----------------*/

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
    // ray marching main loop
    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        SDF scene = sceneSDF(queryPoint);
        float distanceToSurface = scene.sdf;
        // there is an intersection
        if (distanceToSurface < EPSILON)
        {
            
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);
            intersection.material_id = scene.type;
            return intersection;
        }
        // queryPoint = queryPoint + ray.direction * 10.5f;
        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }
    
    intersection.distance = -1.0;
    return intersection;
}

vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).sdf - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).sdf,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).sdf - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).sdf,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).sdf - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).sdf
    ));
}

vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);
    lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 normalize(vec3(1.0, 1.0, 1.0)));
    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                  normalize(vec3(1.0, 0.0, 0.0)));
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                  normalize(vec3(1.0, 0.0, 0.0)));
    
   
    backgroundColor =  normalize(vec3(1.0, 1.0, 0.0));
    
    // water or mountain
    vec3 albedo = intersection.material_id == 1 ? vec3(1.0) : vec3(0.26f, 0.46f, 0.56f);
    vec3 n = estimateNormal(intersection.position);
        
    vec3 color = albedo *
                 lights[0].color *
                 max(0.0, dot(n, lights[0].dir));
    


    
    // sun glare
    // float sun = clamp( dot(kSunDir,rd), 0.0, 1.0 );
    // col += 0.2*vec3(1.0,0.6,0.3)*pow( sun, 32.0 );
    

    // there is intersection, otherwise it is -1
    if (intersection.distance > 0.0)
    { 
        for(int i = 1; i < 3; ++i) {
            color += albedo *
                     lights[i].color *
                     max(0.0, dot(n, lights[i].dir));


        }
                // atmosphere
        float lamda = pow(EULER_NUMBER, -0.0005f * intersection.distance);
        color = lamda * color + (1.0f - lamda) * vec3(0.73f, 0.73f, 0.73f);
    
    }

    // no interaction: sky
    else
    {
        // gradiant sky color
        color = vec3(0.5, 0.7, 0.9);
        color -= 0.4 * uv.y;


        // clouds
        Ray ray = getRay(uv);
        vec3 ro = ray.origin;
        vec3 rd = ray.direction;
        float t = (2500.0-ro.y)/rd.y;
        if( t > 0.0 )
        {
            vec2 uv = (ro+t*rd).xz;
            float cl = fbm( vec3(uv*0.00104, u_Time * 0.004) );
            float dl = smoothstep(0.4,0.6,cl);
            
            color = mix(color, vec3(1.0), 0.12*dl );
        }
    }



        // gamma correction
        color = pow(color, vec3(1. / 2.2));
        return color;
}

/* ---------------- Main Function ----------------*/

void main() {

    out_Col = vec4(getSceneColor(fs_Pos), 1.0f);


}
