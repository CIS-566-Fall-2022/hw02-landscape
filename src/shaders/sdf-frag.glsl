#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec4 u_Color;

in vec2 fs_Pos;
out vec4 out_Col;

#define EPSILON          0.01
#define INFINITY         1000000.0
#define MAX_STEPS        128
#define MAX_DEPTH        100.0
#define MAX_RAY_LENGTH   1000.0

#define KEY_LIGHT        vec3(0.9, 0.8, 0.4) * 1.8
#define FILL_LIGHT       vec3(0.5, 0.85, 0.95) * 0.2
#define AMBIENT_LIGHT    vec3(0.9, 0.8, 0.3) * 0.2

#define PI               3.1415926535897932384626433832795

struct Ray
{
    vec3 origin;
    vec3 direction;
};

struct Intersection
{
    vec3 point;
    vec3 normal;
    float t;
};

struct Material
{
    int type;
    vec3 color;
};

struct DirectionalLight
{
    vec3 direction;
    vec3 color;
};

mat3 rotateY3D(float angle)
{
    return mat3(cos(angle), 0, -sin(angle),
                0, 1, 0, 
                sin(angle), 0, cos(angle));
}

mat3 identity()
{
    return mat3(1, 0, 0,
                0, 1, 0, 
                0, 0, 1);
}

float bias(float b, float t)
{
    return pow(t, log(b) / log(0.5f));
}

// Noise and interpolation functions based on CIS 560 and CIS 566 Slides - "Noise Functions"
float noise2Df(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 noise2Dv( vec2 p ) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5,183.3)))) * 43758.5453);
}

float noise3Df(vec3 p) 
{
    return fract(sin((dot(p, vec3(127.1, 311.7, 191.999)))) * 43758.5453);
}

vec3 noise3Dv(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 191.999)),
                 dot(p, vec3(269.5,183.3,483.1)),
                 dot(p, vec3(564.5,96.3,223.9))))
                 * 43758.5453);
}

float cosineInterpolate(float a, float b, float t)
{
    float cos_t = (1.f - cos(t * PI)) * 0.5f;
    return mix(a, b, cos_t);
}

float interpolateNoise2D(float x, float y) 
{
    // Get integer and fractional components of current position
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);

    // Get noise value at each of the 4 vertices
    float v1 = noise2Df(vec2(intX, intY));
    float v2 = noise2Df(vec2(intX + 1, intY));
    float v3 = noise2Df(vec2(intX, intY + 1));
    float v4 = noise2Df(vec2(intX + 1, intY + 1));

    // Interpolate in the X, Y directions
    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);
    return cosineInterpolate(i1, i2, fractY);
}

float fbm2D(vec2 p) 
{
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 4;

    for(int i = 1; i <= octaves; i++)
    {
        float freq = pow(2.f, float(i));
        float amp = pow(persistence, float(i));

        float perlin = interpolateNoise2D(p.x * freq, p.y * freq);
        total += amp * (0.5 * (perlin + 1.0));
    }
    return total;
}

float worley3D(vec3 p) {
    // Tile space
    p *= 2.0;
    vec3 pInt = floor(p);
    vec3 pFract = fract(p);
    float minDist = 1.0; // Minimum distance

    // Iterate through neighboring cells to find closest point
    for(int z = -1; z <= 1; ++z) {
        for(int y = -1; y <= 1; ++y) {
            for(int x = -1; x <= 1; ++x) {
                vec3 neighbor = vec3(float(x), float(y), float(z)); 
                vec3 point = noise3Dv(pInt + neighbor); // Random point in neighboring cell
                
                // Distance between fragment and neighbor point
                vec3 diff = neighbor + point - pFract; 
                float dist = length(diff); 
                minDist = min(minDist, dist);
            }
        }
    }

    // Set pixel brightness to distance between pixel and closest point
    return minDist;
}

float interpolateNoise3D(float x, float y, float z)
{
    // Get integer and fractional components of current position
    int intX = int(floor(x));
    float fractX = fract(x);
    int intY = int(floor(y));
    float fractY = fract(y);
    int intZ = int(floor(z));
    float fractZ = fract(z);

    // Get noise value at each of the 8 vertices
    float v1 = noise3Df(vec3(intX, intY, intZ));
    float v2 = noise3Df(vec3(intX + 1, intY, intZ));
    float v3 = noise3Df(vec3(intX, intY + 1, intZ));
    float v4 = noise3Df(vec3(intX + 1, intY + 1, intZ));
    float v5 = noise3Df(vec3(intX, intY, intZ + 1));
    float v6 = noise3Df(vec3(intX + 1, intY, intZ + 1));
    float v7 = noise3Df(vec3(intX, intY + 1, intZ + 1));
    float v8 = noise3Df(vec3(intX + 1, intY + 1, intZ + 1));

    // Interpolate in the X, Y, Z directions
    float i1 = cosineInterpolate(v1, v2, fractX);
    float i2 = cosineInterpolate(v3, v4, fractX);
    float mix1 = cosineInterpolate(i1, i2, fractY);
    float i3 = cosineInterpolate(v5, v6, fractX);
    float i4 = cosineInterpolate(v7, v8, fractX);
    float mix2 = cosineInterpolate(i3, i4, fractY);
    return cosineInterpolate(mix1, mix2, fractZ);
}

float fbm3D(vec3 p)
{
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 3;

    for (int i = 1; i < octaves; ++i)
    {
        float freq = pow(2.f, float(i));
        float amp = pow(persistence, float(i));

        total += amp * interpolateNoise3D(p.x * freq, p.y * freq, p.z * freq);
    }

    return total;
}

float worley2D(vec2 p, int animate) {
    // Tile space
    p *= 2.0;
    vec2 pInt = floor(p);
    vec2 pFract = fract(p);
    float minDist = 1.0; // Minimum distance

    // Iterate through neighboring cells to find closest point
    for(int z = -1; z <= 1; ++z) {
        for(int x = -1; x <= 1; ++x) {
            vec2 neighbor = vec2(float(x), float(z)); 
            vec2 point = noise2Dv(pInt + neighbor); // Random point in neighboring cell
            if (animate == 1) point = 0.5 + 0.5 * sin(0.5 * u_Time * 0.1 + 6.2831 * point);
            
            // Distance between fragment and neighbor point
            vec2 diff = neighbor + point - pFract; 
            float dist = length(diff); 
            minDist = min(minDist, dist);
        }
    }
    // Set pixel brightness to distance between pixel and closest point
    return minDist;
}

bool getRayLength(vec3 p, vec3 rayOrigin)
{
    return length(p - rayOrigin) > MAX_RAY_LENGTH;
}

float smoothUnion(float d1, float d2, float k) 
{
    float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
    return mix( d2, d1, h ) - k*h*(1.0-h); 
}

// SDF for a sphere centered at objectPos
float sphereSDF(vec3 rayPos, vec3 objectPos, float radius)
{
    return length(rayPos - objectPos) - radius;
}

float capsuleSDF(vec3 rayPos, vec3 a, vec3 b, float r)
{
    vec3 pa = rayPos - a, ba = b - a;
    float h = clamp(dot(pa, ba)/ dot(ba, ba), 0.0, 1.0);
    return length( pa - ba * h ) - r;
}

float roundedBoxSDF(vec3 rayPos, vec3 objectPos, mat3 transform, vec3 b, float r)
{
    vec3 p = (rayPos - objectPos) * transform; //* rotateY3D(-0.528);
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float planeSDF(vec3 rayPos, float h)
{
    return rayPos.y - h; 
}

float trainSDF(vec3 rayPos, out Material mat)
{
    mat3 id = identity();

    vec3 p = vec3(-250.0, -40.0, -63.5 + 0.8 * mod(u_Time, 300.0));
    float carFront = roundedBoxSDF(rayPos, p, id, vec3(3.0, 1.0, 10.0), 1.0);

    vec3 r = vec3(-250.0, -40.0, -41.5 + 0.8 * mod(u_Time, 300.0));
    float carBack = roundedBoxSDF(rayPos, r, id, vec3(3.0, 1.0, 10.0), 1.0); 

    float dMin = min(carFront, carBack);
    mat.type = 2;
    mat.color = vec3(0.9, 0.1, 0.1);
    return dMin;
}

float groundSDF(vec3 rayPos, out Material mat)
{
    // Water
    float wOffset = 1.0 - worley2D(0.05 * rayPos.xz, 1);
    wOffset += smoothstep(-1.0, 1.0, 29.8 * fract(wOffset));
    float water = planeSDF(rayPos - wOffset, -43.0);

    // Cliff
    float xOffset = fbm2D(0.3 * sin(rayPos.xz + 1.0f));
    float zOffset = cos(0.15 * rayPos.y - 1.0f);
    float cliff = roundedBoxSDF(rayPos, vec3(-45.0 + xOffset, -25.0, -80.0 + zOffset), rotateY3D(-0.508), vec3(20.5, 15.5, 55.5), 5.5);
    float dMin = min(water, cliff);

    // Mountains
    float boundingBox = roundedBoxSDF(rayPos, vec3(-600.0, 0.0, -300.0), rotateY3D(-0.408), vec3(110.5, 50.0, 575.0), 0.0);
    float mountains = INFINITY;
    float mNoise = 0.0;
    if (boundingBox <= EPSILON)
    {
        mNoise = fbm2D(0.01 * rayPos.xz);
        float yOffset = 200.f * mNoise;
        mountains = roundedBoxSDF(rayPos, vec3(-600.0, -253.0 + yOffset, -200.0 - yOffset), rotateY3D(-0.408), vec3(20.5, 0.5, 500.5), 120.5);
        dMin = min(dMin, mountains);
    }
    //dMin = min(dMin, boundingBox);

    // Vegetation
    float wNoise = 2.f * worley2D(0.15 * rayPos.xz, 0);
    //wNoise *= fbm2D(2.5f * rayPos.xz + 5.0);
    float yOffset = smoothstep(0.3, 0.9, 1.0 - wNoise);
    float grass = roundedBoxSDF(rayPos, vec3(-45.0 + xOffset, -10.0 + yOffset, -80.0 + zOffset), rotateY3D(-0.508), vec3(19.0, 2.0, 55.5), 5.5);
    dMin = min(dMin, grass);

    // Assign color
    if (dMin == water)
    {
        mat.type = 3;
        mat.color = mix(vec3(0.1, 0.4, 0.9), vec3(0.2, 0.5, 1.0), wOffset);
    }
    else if (dMin == cliff) 
    {
        mat.type = 4;
        mat.color = vec3(0.8, 0.7, 0.6);
    }
    else if (dMin == mountains) 
    {
        mat.type = 5;
        mat.color = mix(vec3(0.7, 0.3, 0.2), vec3(10.0, 10.0, 10.0), bias(mNoise, 0.01));
    }
    else 
    {
        mat.type = 6;
        mat.color = mix(vec3(0.0, 0.9, 0.0), vec3(0.2, 1.0, 0.3), wNoise);
    }
    
    return dMin;
}

float bridgeSDF(vec3 rayPos, out Material mat)
{
    // Add sine distortion to origin rayPos to make bridge curve up
    vec3 p = rayPos;
    p.y += sin(0.1f * rayPos.z - 1.5f) + 1.8f; 
    mat3 id = identity();

    // Ground planks
    vec3 q = vec3(p.x, p.y, mod(p.z, 0.4));
    float bridgeFloor = roundedBoxSDF(q, vec3(3.0, 0.0, 0.0), id, vec3(2.0, 0.05, 0.35), 0.1);
    float dMin = bridgeFloor;

    // Vertical planks
    q = vec3(p.x, p.y, mod(p.z, 3.0));
    float bridgeVert1 = roundedBoxSDF(q, vec3(1.1, 1.0, 0.0), id, vec3(0.1, 1.0, 0.2), 0.02);
    dMin = min(dMin, bridgeVert1);

    q = vec3(p.x, p.y, mod(p.z + 0.5, 3.0));
    float bridgeVert2 = roundedBoxSDF(q, vec3(1.1, 0.5, 2.0), id, vec3(0.08, 0.5, 0.08), 0.02);
    dMin = min(dMin, bridgeVert2);

    // Horizontal planks
    q = vec3(p.x, p.y, mod(p.z + 5.0, 3.5)) - vec3(0.0, -0.8, 0.0);
    float lower = roundedBoxSDF(q, vec3(1.1, 1.0, 0.0), id, vec3(0.15, 0.09, 3.5), 0.02);
    dMin = min(dMin, lower);

    q = vec3(p.x, p.y, mod(p.z + 5.0, 3.5));
    float lower2 = roundedBoxSDF(q, vec3(1.1, 1.1, 0.0), id, vec3(0.08, 0.1, 3.5), 0.02);
    dMin = min(dMin, lower2);
    
    q = vec3(p.x, p.y, mod(p.z + 5.0, 3.5)) - vec3(0.0, 0.8, 0.0);
    float lower3 = roundedBoxSDF(q, vec3(1.1, 1.2, 0.0), id, vec3(0.2, 0.05, 3.5), 0.02);
    dMin = min(dMin, lower3);

    // Assign color depending on part of bridge
    if (dMin == bridgeFloor)
    {
        mat.type = 0;
        mat.color = vec3(0.5);
    }
    else {
        mat.type = 1;
        mat.color = vec3(0.9, 0.1, 0.1);
    }

    return dMin;
}

float sceneSDF(vec3 rayPos, out Material mat)
{
    Material groundMat;
    float ground = groundSDF(rayPos, groundMat);
    float dMin = ground;

    Material bridgeMat;
    float bridge = bridgeSDF(rayPos, bridgeMat);
    dMin = min(dMin, bridge);

    Material trainMat;
    float train = trainSDF(rayPos, trainMat);
    dMin = min(dMin, train);

    // Assign color
    if (dMin == ground) {
        mat.type = groundMat.type;
        mat.color = groundMat.color;
    }
    else if (dMin == bridge) {
        mat.type = bridgeMat.type;
        mat.color = bridgeMat.color;
    }
    else {
        mat.type = trainMat.type;
        mat.color = trainMat.color;
    }

    return dMin;
}

float f(float x, float z)
{
    return 3.f * fbm2D(0.5 * vec2(x, z));
}

vec3 getBackgroundColor(vec2 uv)
{
    vec3 color = vec3(0.5, 0.85, 0.95);
    float noise = smoothstep(0.61, 0.7, fbm2D(uv + vec2(0.005 * u_Time, 0.0)));
    color = mix(vec3(1.0), color, noise);

    return color;
}

Ray getRay(vec2 uv)
{
    Ray ray;

    float aspect = u_Dimensions.x / u_Dimensions.y;
    float len = tan(3.14159 * 0.125) * distance(u_Eye, u_Ref);
    vec3 H = normalize(cross(vec3(0.0, 1.0, 0.0), u_Ref - u_Eye));
    vec3 V = normalize(cross(H, u_Eye - u_Ref));
    V *= len;
    H *= len * aspect;
    vec3 p = u_Ref + uv.x * H + uv.y * V;
    vec3 dir = normalize(p - u_Eye);

    ray.origin = u_Eye;
    ray.direction = dir;
    return ray;
}

vec3 estimateNormal(vec3 p)
{
    Material mat;
    float gx = sceneSDF(vec3(p.x + EPSILON, p.y, p.z), mat) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z), mat);
    float gy = sceneSDF(vec3(p.x, p.y + EPSILON, p.z), mat) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z), mat);
    float gz = sceneSDF(vec3(p.x, p.y, p.z + EPSILON), mat) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON), mat);
    return normalize(vec3(gx, gy, gz));
}

vec3 editColor(Material mat, vec3 normal)
{
    if (mat.type == 4 || mat.type == 5)
    {
        return smoothstep(0.3, 0.7, mix(mat.color, vec3(0.0, 0.9, 0.0), normal.y));
    }
    return mat.color;
}

float calcShadows(vec3 rayOrigin, vec3 rayDirection, float k)
{
    Material mat;
    float res = 1.0;
    for (float t = 2.0; t < float(MAX_STEPS); ++t)
    {
        vec3 p = rayOrigin + t * rayDirection;
        if (getRayLength(p, rayOrigin)) break; 
        float s = sceneSDF(p, mat);
        if (s < EPSILON)
        {
            return 0.0;
        }
        res = min(res, k * s / t);
        t += s;
    }
    return res;
}

Intersection raymarch(vec2 uv, Ray ray, out Material mat)
{
    Intersection intersection;

    vec3 p = ray.origin;
    for (int i = 0; i < MAX_STEPS; ++i)
    {     
        // If ray is too long, skip (avoid testing empty space)
        if (getRayLength(p, ray.origin)) break; 

        float dist = sceneSDF(p, mat);
        if (dist < EPSILON)
        {
            intersection.point = p;
            intersection.normal = estimateNormal(p);
            intersection.t = length(p - ray.origin);
            mat.color = editColor(mat, intersection.normal);
            return intersection;
        }
        if (intersection.t > MAX_DEPTH)
        {
            break;
        }
        p = p + dist * ray.direction;
    }
    intersection.t = -1.0;
    return intersection;
}

Intersection raymarchTerrain(vec2 uv, Ray ray)
{
    Intersection intersection;

    for (float t = 0.f; t < 5.f; t += 0.01f)
    {     
        vec3 p = ray.origin + t * ray.direction;  
        float height = f(p.x, p.z);
        if (p.y < height)
        {
            intersection.normal = estimateNormal(p);
            //intersection.t = length(p - ray.origin);
            intersection.t = t;
            return intersection;
        }       
    }
    intersection.t = -1.0;
    return intersection;
}

void main() {

    // Material base color (before shading)
    vec3 albedo = vec3(0.5);
    vec3 color = vec3(0.0);

    // Lights
    DirectionalLight lights[3];
    lights[0] = DirectionalLight(normalize(vec3(-10.0, 20.0, -20.0)), KEY_LIGHT);
    lights[1] = DirectionalLight(normalize(vec3(0.0, 1.0, 0.0)), FILL_LIGHT);
    lights[2] = DirectionalLight(normalize(-vec3(-10.0, 0.0, -20.0)), AMBIENT_LIGHT);

    // Raymarch scene
    vec2 ndc = gl_FragCoord.xy / u_Dimensions.xy;
    ndc = ndc * 2.0 - 1.0;
    Ray ray = getRay(ndc);

    Material mat;
    Intersection isect = raymarch(ndc, ray, mat);
    //Intersection isect = raymarchTerrain(ndc, ray);

    // Lighting calculations
    if (isect.t > 0.0) 
    {
        for (int i = 0; i < 3; i++)
        {
            //float shadow = calcShadows(isect.point, lights[i].direction, 3.0);
            float shadow = 1.0;
            float cosTheta = max(0.0, dot(isect.normal, lights[i].direction));
            color += mat.color * lights[i].color * cosTheta * clamp(0.0, 0.5, shadow);
        }    
    }
    else 
    {
        color = getBackgroundColor(ndc);
    }

    // Distance fog
    vec3 fog_dist = exp(-0.001 * isect.t * vec3(1.0, 1.5, 1.7));
    vec3 fog_t = smoothstep(0.0, 0.8, fog_dist);
    color = mix(vec3(0.5, 0.85, 0.85), color, fog_t);

    // Final color correction
    color = pow(color, vec3(1.0, 0.9, 1.0)) + vec3(0.0, 0.0, 1.0) * 0.01;
    color = pow(color, vec3(1.0 / 2.2));

    // Compute final shaded color
    out_Col = vec4(color.rgb, 1.0);
}
