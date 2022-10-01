#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;


const int MAX_RAY_STEPS = 256;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);
const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;

// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define GRASS_COLOR vec3(0.0, 0.2, 0.5) * 1.5
#define OCEAN_COLOR vec3(0.0, 0.329, 0.576) * 1.5
#define ROCK_COLOR vec3(1.0, 0.3, 0.0) * 1.5
#define LAVA_COLOR vec3(1.0, 0.1, 0.0) * 1.5

// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.0, 0.0, 0.2) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.9, 1.0, 0.9) * 0.2

// TOOLBOX FUNCTIONS
float noise_gen1_1(float x)
{
    return fract(sin(x * 127.1) * 43758.5453);
}
float noise_gen2_1( vec2 p) 
{
    return fract(sin(dot(p.xy,
                         vec2(12.9898,78.233)))*
        43758.5453123);
}
vec2 noise_gen2_2(vec2 p)
{
    return fract(sin(vec2(dot(p, vec2(127.1f, 311.7f)),
                     dot(p, vec2(269.5f,183.3f))))
                     * 43758.5453f);
}
float noise_gen3_1(vec3 p)
{
    return fract(sin((dot(p, vec3(127.1, 311.7, 191.999)))) * 43758.5453);
}
float noise_gen4_1(vec4 p)
{
    return fract(sin((dot(p, vec4(127.1, 311.7, 191.999, 433.7)))) * 43758.5453);
}

float interpNoise1D (float noise) {
    float intX = float(floor(noise));
    float fractX = fract(noise);
    float v1 = noise_gen1_1(intX);
    float v2 = noise_gen1_1(intX + 1.0);
    return mix(v1, v2, fractX);
}
float interpNoise2D (vec2 noise) {
    int intX = int(floor(noise.x));
    float fractX = fract(noise.x);
    int intY = int(floor(noise.y));
    float fractY = fract(noise.y);
    float v1 = noise_gen2_1(vec2(intX, intY));
    float v2 = noise_gen2_1(vec2(intX + 1, intY));
    float v3 = noise_gen2_1(vec2(intX, intY + 1));
    float v4 = noise_gen2_1(vec2(intX + 1, intY + 1));
    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    return mix(i1, i2, fractY);
}
float interpNoise3D(vec3 noise)
{
    int intX = int(floor(noise.x));
    float fractX = fract(noise.x);
    int intY = int(floor(noise.y));
    float fractY = fract(noise.y);
    int intZ = int(floor(noise.z));
    float fractZ = fract(noise.z);

    float v1 = noise_gen3_1(vec3(intX, intY, intZ));
    float v2 = noise_gen3_1(vec3(intX + 1, intY, intZ));
    float v3 = noise_gen3_1(vec3(intX, intY + 1, intZ));
    float v4 = noise_gen3_1(vec3(intX + 1, intY + 1, intZ));
    float v5 = noise_gen3_1(vec3(intX, intY, intZ + 1));
    float v6 = noise_gen3_1(vec3(intX+1, intY, intZ + 1));
    float v7 = noise_gen3_1(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise_gen3_1(vec3(intX+1, intY+1, intZ + 1));

    float i1 = mix(v1, v2, fractX);
    float i2 = mix(v3, v4, fractX);
    float i3 = mix(v5, v6, fractX);
    float i4 = mix(v7, v8, fractX);

    float ii1 = mix(i1, i2, fractY);
    float ii2 = mix(i3, i4, fractY);

    return mix(ii1, ii2, fractZ);
}
float fbm1D(float noise)
{
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.0f;
    float amp = 0.5f;
    
    for (int i=1; i<=octaves; i++)
    {
        total += interpNoise1D(noise * freq) * amp;
        freq *= 2.0f;
        amp *= persistence;
    }
    return total;
}
float fbm2D(vec2 noise)
{
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 2.0f;
    float amp = 0.5f;
    
    for (int i=1; i<=octaves; i++)
    {
        total += interpNoise2D(noise * freq) * amp;
        freq *= 2.0f;
        amp *= persistence;
    }
    return total;
}
float fbm3D(vec3 noise, float amp)
{
    float total = 0.0f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 1.0f;
    
    for (int i=1; i<=octaves; i++)
    {
        total += interpNoise3D(noise * freq) * amp;
        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}
float wolry2D(vec2 p) 
{
    vec2 pInt = floor(p);
    vec2 pFract = fract(p);
    float minDist = 1.0; // Minimum distance initialized to max.
            for(int y = -1; y <= 1; ++y) 
        {
            for(int x = -1; x <= 1; ++x) 
            {
                vec2 neighbor = vec2(float(x), float(y)); // Direction in which neighbor cell lies                                
                vec2 diff = neighbor - pFract; // Distance between fragment coord and neighbor’s Voronoi point
                float dist = length(diff);
                minDist = min(minDist, dist);
            }
        }
    return minDist;
}
float worley3D(vec3 p) 
{
    vec3 pInt = floor(p);
    vec3 pFract = fract(p);
    float minDist = 1.0; // Minimum distance initialized to max.
    for (int z = -1; z <= 1; ++z)
    {
        for(int y = -1; y <= 1; ++y) 
        {
            for(int x = -1; x <= 1; ++x) 
            {
                vec3 neighbor = vec3(float(x), float(y), float(z)); // Direction in which neighbor cell lies             
                vec3 diff = neighbor - pFract; // Distance between fragment coord and neighbor’s Voronoi point
                float dist = length(diff);
                minDist = min(minDist, dist);
            }
        }
    }
    return minDist;
}
// Expected input domain [0.0, 1.0]
float sinSmooth(float x)
{
    return sin(x * 3.14159 * 0.5);
}
float square_wave(float x, float freq, float amplitude)
{
    return abs( float(int(floor(x * freq)) % 2) * amplitude);
}
float bias(float b, float t)
{
    return pow(t, log(b) / log(0.5f));
}
float gain(float g, float t)
{
    if(t<0.5)
    return bias(1.0-g, 2.0*t) /2.0;
    else
    return 1.0-bias(1.0-g, 2.0-2.0*t) / 2.0;
}

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

vec3 bendPoint(vec3 p, float k)
{
    float c = cos(k*p.y);
    float s = sin(k*p.y);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3(m*p.xy,p.z);
    return q;
}

struct Geo
{
    int material_id;
    float dist;
};

Geo minSDF(Geo geo1, Geo geo2)
{
    if (geo1.dist < geo2.dist)
    {
        return geo1;
    }
    return geo2;
}

float heightField(vec3 queryPos, float planeHeight)
{
    return queryPos.y - planeHeight;
}

Geo sceneSDF(vec3 queryPos) 
{
    Geo plane;
    Geo sphere;
    Geo sphere2;
    Geo capsule;

    Geo scene;
    
    float time = u_Time / 1000.0;
    

    plane.dist = planeSDF(queryPos, 1.0);
    sphere.dist = sphereSDF(queryPos, vec3(0.0, -1.0, 5.0) +  fbm3D(queryPos + time, 0.5), 5.0);
    sphere2.dist = sphereSDF(queryPos, vec3(0.0, -1.0, 0.0), 8.0);

    float height = heightField(queryPos,fbm3D(queryPos, 1.f));
    scene.dist = height;

    // float fbmNoise = fbm3D(queryPos, 0.4);
    
    //     scene.dist -= fbmNoise;

    // if (fbmNoise < 0.4)
    // {
    //     scene.material_id = 2;
    // }

    // if (fbmNoise > 0.5)
    // {
    //     scene.material_id = 3;
    // }

    float worley = worley3D(queryPos / 100.0 + fbm3D(queryPos + time, 1.0));

    //scene.dist = plane.dist;

    if(worley > 0.5)
    {
        scene.material_id = 2;
    }
    else if (worley < 0.2)
    {
    scene.material_id = 3;
    }

    if (sphere.dist < EPSILON * 100.0)
    {
        scene.material_id = 4;
    }
    
    scene.dist = heightField(queryPos, 1.0 * worley);
    //Geo fbmTerrain;
    //fbmTerrain.dist  = planeSDF(1.0 * sinSmooth(fbm3D(queryPos, 1.f)) + queryPos, 0.0);
    scene.dist = smoothSubtraction(sphere.dist, scene.dist, 0.2);
    
    // for (int i=0; i<10; ++i)
    // {
    //     float x = worley3D(queryPos);
    //     float z = fbm3D(queryPos, 1.0);
    //     capsule.dist = capsuleSDF(queryPos, vec3(float(i) * x, 10.0 - 10.0 * (fract(u_Time / 100.0)), float(i) * z), vec3(float(i) *x, 0.1 + 10.0 - 10.0 * (fract(u_Time/ 100.0)), float(i) *z), 0.01);
    //     scene.dist = smoothUnion(capsule.dist, scene.dist, 0.0);
    // }

   return scene;
}
float softShadow(in vec3 ro, in vec3 rd, float mint, float maxt, float k)
{
    float res = 1.0;
    for (float t=mint; t<maxt;)
    {
        float h = sceneSDF(ro + rd*t).dist;
        if (h<0.001)
        {
            return 0.0;
        }
        res = min(res, k*h/t);
        t += h;
    }
    return res;
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
        Geo sceneGeo =  sceneSDF(queryPoint);
        float distanceToSurface = sceneGeo.dist;
        
        if (distanceToSurface < EPSILON)
        {
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);          
            intersection.material_id = sceneGeo.material_id;
            return intersection;
        }
        queryPoint = queryPoint + ray.direction * distanceToSurface;
    }
    
    intersection.distance = -1.0;
    return intersection;
}

vec3 estimateNormal(vec3 p  ) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)).dist - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)).dist,
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)).dist - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)).dist,
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)).dist - sceneSDF(vec3(p.x, p.y, p.z - EPSILON)).dist
    ));
}

vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);

    if (intersection.material_id == 2)
        lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 OCEAN_COLOR);
    else if (intersection.material_id == 3)
        lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 ROCK_COLOR);
    else if (intersection.material_id == 4)
    {
    // #define ROCK_COLOR vec3(1.0, 0.3, 0.0) * 1.5
    // #define LAVA_COLOR vec3(1.0, 0.1, 0.0) * 1.5    
        vec3 c1 = vec3(1.0, 0.3, 0.0);
        vec3 c2 = vec3(1.0, 0.1, 0.0);
        vec3 color = mix(c2, c1, intersection.position.y /2.5 + 1.0);
        lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 color);
    }
    else
        lights[0] = DirectionalLight(normalize(vec3(15.0, 15.0, 10.0)),
                                 GRASS_COLOR);

    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);
    backgroundColor = GRASS_COLOR;
    
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
        //color = vec3(0.5, 0.7, 0.9);
        color = vec3(0.0, 0.0, 0.1);
    }
        color = pow(color, vec3(1. / 2.2));
        return color;
}


void main() {
    vec2 uv = gl_FragCoord.xy/u_Dimensions.xy;
    uv = uv * 2.0 - 1.0;
    vec3 col = getSceneColor(uv);
    
    // Compute final shaded color
    out_Col = vec4(col, 1.0);
}
