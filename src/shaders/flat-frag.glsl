#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;


const int MAX_RAY_STEPS = 128;
const float MAX_RAY_Z = 1000.0;
const float FOV = 45.0;
const float EPSILON = 1e-2;

const vec3 WORLD_UP = vec3(0.0, 1.0, 0.0);
const vec3 WORLD_RIGHT = vec3(-1.0, 0.0, 0.0);
const vec3 WORLD_FORWARD = vec3(0.0, 0.0, 1.0);
const vec3 LIGHT_DIR = vec3(0.6, 1.0, 0.4) * 1.5;


// Want sunlight to be brighter than 100% to emulate
// High Dynamic Range
#define ICE_COLOR vec3(0.8314, 0.9451, 0.9765) * 1.5
#define WATER_COLOR vec3(0.0588, 0.3686, 0.6117) * 1.5
#define LAVA_COLOR vec3(0.81, 0.19, 0.063) * 1.5
#define FIRE_COLOR vec3(0.81, 0.188, 0.063) * 1.5

#define CLOUD_COLOR vec3(0.18, 0.266, 0.5098) 
#define SKY_COLOR vec3(0.5, 0.7, 0.9)


// Fill light is sky color, fills in shadows to not be black
#define SKY_FILL_LIGHT vec3(0.18, 0.266, 0.5098) * 0.2
// Faking global illumination by having sunlight
// bounce horizontally only, at a lower intensity
#define SUN_AMBIENT_LIGHT vec3(0.9, 1.0, 0.9) * 0.2

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

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
    float height;
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
    float height;
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


vec3 opRep( in vec3 p, in vec3 c)
{
    //c -= fbm2D(fs_Pos * 0.01);
    return mod(p + 0.5 * c + cos(u_Time / 1000.0) , c) - 0.5  * c ;
}
vec3 opRepLim( in vec3 p, in float s, in vec3 lima, in vec3 limb )
{
    return p-s*clamp(round(p/s),lima,limb);
}

Geo sceneSDF(vec3 queryPos) 
{
    Geo plane;
    Geo sphere;
    Geo capsule;
        
    Geo spherePlanet;


    Geo scene;
    
    float time = u_Time / 1000.0;
    

    plane.dist = planeSDF(queryPos, 1.0);
    sphere.dist = sphereSDF(queryPos, vec3(0.0, 0.0, 5.0) +  fbm3D(queryPos + time, 0.5), 5.0);
    
    spherePlanet.dist = sphereSDF(queryPos, vec3(-20.0, 10.0, 50.0) , 0.8);
    

    float height = heightField(queryPos,fbm3D(queryPos, 1.f));
    scene.dist = height;


    float worley = worley3D(queryPos / 100.0 + fbm3D(queryPos + time, 1.0));

    if(worley > 0.5)
    {
        scene.material_id = 2;
    }
    else if (worley < 0.4)
    {
        scene.material_id = 3;
    }

    if (sphere.dist < EPSILON * 100.0)
    {
        scene.material_id = 4;
    }
    if (spherePlanet.dist < EPSILON * 100.0)
    {
        scene.material_id = 5;
    }
    
    scene.dist = heightField(queryPos, 1.0 * worley);

    scene.dist = smoothSubtraction(sphere.dist, scene.dist, 0.2);
    scene.dist = smoothUnion(spherePlanet.dist, scene.dist, 0.2);
    //scene.dist = smoothUnion(scene.dist, sphereSDF(opRep(queryPos, vec3(2.0, 2.0 - fract(u_Time / 1000.0), 2.0)), vec3(0.0, 0.0, 0.0), 0.01 + 0.01 * fbm3D(queryPos, 1.0)), 0.2);
    // float snow = sphereSDF(opRep(queryPos - vec3(0.0, - u_Time / 500.0, 0.0), vec3(1.0, 1.0 , 1.0)), vec3(0.0, 0.0, 0.0), 0.01);
    // if (snow < EPSILON)
    // {
    //     scene.material_id = 2;
    // }
    //scene.dist = snow;
    //scene.dist = smoothUnion(scene.dist, snow, 0.1); 
    scene.height = worley;
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

bool isRayTooLong(vec3 queryPoint, vec3 origin)
{
    return length(queryPoint - origin) > MAX_RAY_Z;
}

Intersection getRaymarchedIntersection(vec2 uv)
{
    Ray ray = getRay(uv);
    Intersection intersection;
    
    vec3 queryPoint = ray.origin;


    for (int i=0; i < MAX_RAY_STEPS; ++i)
    {
        if (isRayTooLong(queryPoint, ray.origin)) break;

        Geo sceneGeo =  sceneSDF(queryPoint);
        float distanceToSurface = sceneGeo.dist;
        
        if (distanceToSurface < EPSILON)
        {
            intersection.position = queryPoint;
            intersection.normal = vec3(0.0, 0.0, 1.0);
            intersection.distance = length(queryPoint - ray.origin);          
            intersection.material_id = sceneGeo.material_id;
            intersection.height= sceneGeo.height;
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

float getCloud(vec3 origin, vec3 dir) {
  float t = (1000.0 - origin.y) / dir.y;
  vec3 pos = origin + dir * t + vec3(0.0,0.0,u_Time);
  float clouds = fbm3D(vec3(pos.xz * 0.001, u_Time / 100.0), 1.0);
  return clouds;
}


vec3 getSceneColor(vec2 uv)
{
    Intersection intersection = getRaymarchedIntersection(uv);
    
    vec3 dirLight = vec3(15.0, 15.0, 10.0);
    vec3 dirLight2 = vec3(0, 100.0, 5.0);

    DirectionalLight lights[3];
    vec3 backgroundColor = vec3(0.);

    if (intersection.material_id == 2)
        lights[0] = DirectionalLight(normalize(dirLight),
                                 mix(WATER_COLOR,ICE_COLOR, 2.0 * (intersection.height - 0.5)));
    else if (intersection.material_id == 3)
        lights[0] = DirectionalLight(normalize(dirLight),
                                 mix(mix(1.0, 2.0,fbm3D(intersection.position, 0.5)) * LAVA_COLOR, WATER_COLOR, intersection.height * 2.5));
    else if (intersection.material_id == 4)
    { 
        vec3 color = mix(FIRE_COLOR, LAVA_COLOR, map(intersection.position.y, 0.0, 1.0, -20.0, 0.0));
        color *= mix(1.0, 2.0, fbm3D(intersection.position, 0.5) / 1000.0);
        lights[0] = DirectionalLight(normalize(dirLight2),
                                 color);
    }
    else if(intersection.material_id == 5)
    { 
        lights[0] = DirectionalLight(normalize(dirLight),
                                mix(1.0, 1.5,fbm1D(u_Time / 500.0)) * mix(ICE_COLOR,WATER_COLOR, fbm2D(intersection.position.xz) ) );

        return lights[0].color;
    }
    else
    {
        lights[0] = DirectionalLight(normalize(dirLight),
                                 WATER_COLOR);
    }


    lights[1] = DirectionalLight(vec3(0., 1., 0.),
                                 SKY_FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(15.0, 0.0, 10.0)),
                                 SUN_AMBIENT_LIGHT);

    backgroundColor = WATER_COLOR;
    
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

        float clouds = getCloud(u_Eye, getRay(fs_Pos).direction);
        color =  mix(SKY_COLOR, CLOUD_COLOR, clouds) * 0.1;
    }
        color = mix(color, CLOUD_COLOR * 0.2, clamp(0.0, 1.0, intersection.distance / 80.0));
        color = pow(color, vec3(1. / 2.2));
        return color;
}


void main() {
    vec2 uv = gl_FragCoord.xy/u_Dimensions.xy;
    uv = uv * 2.0 - 1.0;
    vec3 col = getSceneColor(uv);

    float time = u_Time / 1000.0;

// https://www.shadertoy.com/view/Mdt3Df
    float snow = 0.0;
    for(int k=0;k<12;k++){
        for(int i=0;i<24;i++){
            float cellSize = 0.01 + (float(i)*5.0);
			float downSpeed = 0.6+(sin(time*0.4+float(k+i*20))+1.0)*0.00008;
            vec2 uv = (gl_FragCoord.xy / u_Dimensions.x)+vec2(0.01*sin((time+float(k*6185))*0.6+float(i))*(5.0/float(i)),downSpeed*(time+float(k*1352))*(1.0/float(i)));

            vec2 uvStep = (ceil((uv)*cellSize-vec2(0.5,0.5))/cellSize);
            float x = fract(sin(dot(uvStep.xy,vec2(12.9898+float(k)*12.0,78.233+float(k)*315.156)))* 43758.5453+float(k)*12.0)-0.5;
            float y = fract(sin(dot(uvStep.xy,vec2(62.2364+float(k)*23.0,94.674+float(k)*95.0)))* 62159.8432+float(k)*12.0)-0.5;

            float randomMagnitude1 = sin(time*2.5)*0.7/cellSize;
            float randomMagnitude2 = cos(time*2.5)*0.7/cellSize;

            float d = 5.0*distance((uvStep.xy + vec2(x*sin(y),y)*randomMagnitude1 + vec2(y,x)*randomMagnitude2),uv.xy);

            float omiVal = fract(sin(dot(uvStep.xy,vec2(32.4691,94.615)))* 31572.1684);
            if(omiVal<0.08?true:false){
                float newd = (x+1.0)*0.4*clamp(1.9-d*(15.0+(x*6.3))*(cellSize/1.4),0.0,1.0);

                snow += newd;
            }
        }
    }

    out_Col = vec4(mix(col, vec3(mix(0.8, 1.0, snow)), snow) , 1.0);
}
